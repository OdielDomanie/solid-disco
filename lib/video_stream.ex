defmodule VideoStream do
  alias VideoStream.HLS

  @spec video_stream(binary(), binary(), :hls | :dash) :: Enum.t()
  def video_stream(vid_url, format_string, protocol)

  def video_stream(vid_url, fmt_string, :hls) do
    HLS.vid_stream(vid_url, fmt_string)
  end

  def video_stream(vid_url, fmt_string, :dash) do
    Dash.vid_stream(vid_url, fmt_string)
  end
end
