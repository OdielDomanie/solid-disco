defmodule VideoStreamTest do
  use ExUnit.Case
  doctest VideoStream

  @mpegts_magicbyte ?G
  @mpegts_magic_period 188

  test "Return mpeg-ts binary stream from HLS live-stream" do
    # Use some NASA live-stream that's on for at least a few years.
    test_livestream = "https://www.youtube.com/watch?v=21X5lGlDOfg"
    # 720p60, mp4a
    test_format = "300"

    segment_stream = VideoStream.hls_stream(test_livestream, test_format)

    for {segment, segment_info} <- Stream.take(segment_stream, 10) do
      assert %{
               url: _path,
               seq: _seq,
               vtime: _ts,
               wctime: _wct,
               duration: _duration,
               expiry: _expiry
             } = segment_info

      assert Map.get(segment_info, :vtime) or Map.get(segment_info, :wctime)

      # Check the magic bytes to confirm it is an mpeg-ts segment.
      segment_list = :binary.bin_to_list(segment)

      assert segment_list
             |> Enum.take_every(@mpegts_magic_period)
             |> Enum.map(&(@mpegts_magicbyte == &1))
             |> Enum.all?()
    end
  end

  test "Return the dash segments of a given timestamp from a DASH stream." do
    # TODO: Get this from an environment variable
    # NASA stream
    # This stream is so old the sequence math doesn't work.
    # test_video = "https://www.youtube.com/watch?v=21X5lGlDOfg"
    test_video = "https://www.youtube.com/watch?v=lnGbggiGdo8"
    # 720p60 avc1.4d4020 video
    test_format = "298"

    # stream_start = ~U[2018-12-28 00:00:01Z]
    stream_start = ~U[2023-04-03 00:00:01Z]

    ed = DateTime.diff(DateTime.now!("Etc/UTC"), stream_start) - 24 * 3600
    st = (ed - 15) |> IO.inspect()

    [{:audio, _audio_stream}, {:video, video_stream}] =
      VideoStream.dash_segments(test_video, test_format, {st, ed})

    returned_ed =
      for {segment, segment_info} <- Stream.take(video_stream, 17), reduce: nil do
        prev ->
          %{
            url: _path,
            seq: _seq,
            vtime: ts,
            wctime: _wct,
            duration: duration,
            expiry: _expiry
          } = segment_info

          if !prev do
            # First segment (we are tolerant)
            assert_in_delta st, ts, 5
            assert ts <= st
            IO.inspect(ts)
          else
            # No gaps?
            assert_in_delta prev, ts, 0.01
            IO.inspect(ts)
          end

          # Check the magic bytes to confirm it is an mpeg-ts segment.

          assert String.starts_with?(segment, "\0\0\0\x1Cftypdash"),
                 inspect(segment, binaries: :as_strings)

          ts + duration
      end

    assert_in_delta ed, returned_ed, 5
    assert ed <= returned_ed
  end

  # test "Return the m4a segments of a given timestamp from a DASH stream." do
  #   # Same as above but sound (with DASH, vid and sound are usually different streams.).
  # end
end
