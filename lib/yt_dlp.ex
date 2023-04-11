defmodule YtDlp do
  @moduledoc """
  yt-dlp related functions.
  """

  require Logger

  @spec fetch_playlist_url(String.t(), String.t()) ::
          {:error, {:multiple_playlists | pos_integer, binary() | list(binary())}}
          | {:ok, binary()}
  @doc """
  Runs yt-dlp with the `-g` argument, returns the outputted playlist url.
  Can only return one playlist, returns error if it encounters non-one number
  of playlists.
  """
  def fetch_playlist_url(video_url, format \\ "301") do
    cmd = yt_dlp_path() ++ [video_url, "-f", format, "-g"]
    cmd_string = cmd |> Enum.map(fn s -> "\"#{s}\"" end) |> Enum.join(" ")

    Logger.debug("Running: #{cmd_string}")

    case System.cmd(hd(cmd), tl(cmd)) do
      # First check return code, then make sure there is only one url.
      {playlist_urls, 0} ->
        case String.split(playlist_urls) do
          [playlist_url] ->
            Logger.debug("Playlist url #{inspect(playlist_url)}")
            {:ok, playlist_url}

          playlist_list ->
            {:error, {:multiple_playlists, playlist_list}}
        end

      {output, err_code} ->
        {:error, {err_code, output}}
    end
  end

  @doc """
  See `fetch_playlist_url/1`.
  """
  @spec fetch_playlist_url!({binary, binary}) :: binary
  def fetch_playlist_url!({video_url, format}) do
    case fetch_playlist_url(video_url, format) do
      {:ok, playlist_url} -> playlist_url
      error -> raise inspect(error)
    end
  end

  def fetch_mpd(video_url, _format_string) do
    cmd =
      yt_dlp_path() ++
        [
          video_url,
          "--live-from-start",
          "-g"
        ]

    cmd_string = cmd |> Enum.map(fn s -> "\"#{s}\"" end) |> Enum.join(" ")

    Logger.debug("Running: #{cmd_string}")

    case System.cmd(hd(cmd), tl(cmd)) do
      # First check return code.
      {playlist_urls, 0} ->
        {:ok, String.split(playlist_urls) |> hd()}

      {output, err_code} ->
        {:error, {err_code, output}}
    end
  end

  defp yt_dlp_path do
    [Python.Server.python_path(), "-m", "yt_dlp"]
  end
end
