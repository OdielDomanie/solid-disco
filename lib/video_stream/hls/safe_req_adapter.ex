defmodule VideoStream.HLS.SafeReqAdapter do
  @moduledoc """
  Adapter for `Req` that uses `Finch.stream/5` instead of `Finch.request/3`,
  and throws if header or body is non-conforming before downloading the rest.

  `run_finch/1`, `finch_name/1`, `update_finch_request/2` functions are  modified from:
  https://github.com/wojtekmach/req/blob/v0.3.5/lib/req/steps.ex#L568
  under the license:

  Copyright (c) 2021 Wojtek Mach

  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
  You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
  """

  @doc """
  Takes a keyword list of optional
  `headers?: (headers -> bool)` and  `body?: (binary() -> bool)`,
  and returns a Req adapter that halts the download when any of these
  return falsy.
  """
  def safe_adapter(safe_opts) do
    &run_finch(&1, safe_opts)
  end

  defp finch_safe_req(finch_request, finch_name, finch_options, safe_opts) do
    fun = fn
      {:status, status}, {_, headers, body} ->
        {status, headers, body}

      {:headers, headers}, {status, headers_acc, body} ->
        headers_all = headers_acc ++ headers

        headers? = Keyword.get(safe_opts, :headers?)

        if !!headers? && headers?.(headers_all) do
          {status, headers_all, body}
        else
          throw({:bad_header, headers_all})
        end

      {:data, body_bin}, {status, headers, body_acc} ->
        # binary concat is optimized: https://www.erlang.org/doc/efficiency_guide/binaryhandling.html#constructing-binaries
        body_all = body_acc <> body_bin

        body? = Keyword.get(safe_opts, :body?)

        if !!body? && body?.(body_all) do
          {status, headers, body_all}
        else
          throw({:bad_body, body_all})
        end
    end

    with {:ok, {status, headers, body}} <-
           Finch.stream(
             finch_request,
             finch_name,
             {nil, [], []},
             fun,
             finch_options
           ) do
      %{status: status, headers: headers, body: body}
    end
  end

  defp run_finch(request, safe_opts) do
    finch_name = finch_name(request)

    finch_request =
      Finch.build(request.method, request.url, request.headers, request.body)
      |> Map.replace!(:unix_socket, request.options[:unix_socket])
      |> update_finch_request(request)

    finch_options =
      request.options |> Map.take([:receive_timeout, :pool_timeout]) |> Enum.to_list()

    try do
      case finch_safe_req(finch_request, finch_name, finch_options, safe_opts) do
        {:ok, response} ->
          response = %Req.Response{
            status: response.status,
            headers: response.headers,
            body: response.body
          }

          {request, response}

        {:error, exception} ->
          {request, exception}
      end
    catch
      error -> {request, RuntimeError.exception(error)}
    end
  end

  defp finch_name(request) do
    case Map.fetch(request.options, :finch) do
      {:ok, name} ->
        if request.options[:connect_options] do
          raise ArgumentError, "cannot set both :finch and :connect_options"
        end

        name

      :error ->
        if options = request.options[:connect_options] do
          Req.Request.validate_options(
            options,
            MapSet.new([
              :timeout,
              :protocol,
              :transport_opts,
              :proxy_headers,
              :proxy,
              :client_settings
            ])
          )

          hostname_opts = Keyword.take(options, [:hostname])

          transport_opts = [
            transport_opts:
              Keyword.merge(
                Keyword.take(options, [:timeout]),
                Keyword.get(options, :transport_opts, [])
              )
          ]

          proxy_headers_opts = Keyword.take(options, [:proxy_headers])
          proxy_opts = Keyword.take(options, [:proxy])
          client_settings_opts = Keyword.take(options, [:client_settings])

          pool_opts = [
            conn_opts:
              hostname_opts ++
                transport_opts ++
                proxy_headers_opts ++
                proxy_opts ++
                client_settings_opts,
            protocol: options[:protocol] || :http1
          ]

          name =
            options
            |> :erlang.term_to_binary()
            |> :erlang.md5()
            |> Base.url_encode64(padding: false)

          name = Module.concat(Req.FinchSupervisor, "Pool_#{name}")

          case DynamicSupervisor.start_child(
                 Req.FinchSupervisor,
                 {Finch, name: name, pools: %{default: pool_opts}}
               ) do
            {:ok, _} ->
              name

            {:error, {:already_started, _}} ->
              name
          end
        else
          Req.Finch
        end
    end
  end

  defp update_finch_request(finch_request, request) do
    case Map.fetch(request.options, :finch_request) do
      {:ok, fun} -> fun.(finch_request)
      :error -> finch_request
    end
  end
end
