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
    yt_dlp_path = Path.join(:code.priv_dir(:video_stream), "yt-dlp")

    Logger.debug("Running: \"#{yt_dlp_path}\" \"#{video_url}\" -f \"#{format}\" -g")

    case System.cmd(yt_dlp_path, [
           video_url,
           "-f",
           format,
           "-g"
         ]) do
      # First check return code, then make sure there is only one url.
      {playlist_urls, 0} ->
        case String.split(playlist_urls) do
          [playlist_url] -> {:ok, playlist_url}
          playlist_list -> {:error, {:multiple_playlists, playlist_list}}
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
    yt_dlp_path = Path.join(:code.priv_dir(:video_stream), "yt-dlp")

    Logger.debug("Running: \"#{yt_dlp_path}\" \"#{video_url}\" --live-from-start -g")

    case System.cmd(yt_dlp_path, [
           video_url,
           "--live-from-start",
           "-g"
         ]) do
      # First check return code.
      {playlist_urls, 0} ->
        {:ok, String.split(playlist_urls) |> hd()}

      {output, err_code} ->
        {:error, {err_code, output}}
    end
  end
end
