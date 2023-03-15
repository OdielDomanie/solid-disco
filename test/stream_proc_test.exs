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

    segment_stream = VideoStream.video_stream(test_livestream, test_format, :hls)

    for {segment, segment_info} <- Stream.take(segment_stream, 10) do
      assert %{
               path: _path,
               seq: _seq,
               time: _time,
               duration: _duration,
               expiry: _expiry
             } = segment_info

      # Check the magic bytes to confirm it is an mpeg-ts segment.
      segment_list = :binary.bin_to_list(segment)

      assert segment_list
             |> Enum.take_every(@mpegts_magic_period)
             |> Enum.map(&(@mpegts_magicbyte == &1))
             |> Enum.all?()
    end
  end

  test "Return the mpeg-ts segments of a given timestamp from a DASH stream." do
    test_video = "TODO"
    test_format = "TODO"

    {st, ed} = {??, ??}

    segment_stream = VideoStream.segments_of(test_video, test_format, {st, ed})

    returned_ed =
      for {segment, segment_info} <- Stream.take(segment_stream, 10), reduce: nil do
        prev ->
          %{
            path: _path,
            seq: _seq,
            timestamp: ts,
            duration: duration,
            expiry: _expiry
          } = segment_info

          if !prev do
            # First segment (we are tolerant)
            assert_in_delta st, ts, 5
            assert ts <= st
          else
            # No gaps?
            assert_in_delta prev, ts, 0.01
          end

          # Check the magic bytes to confirm it is an mpeg-ts segment.
          segment_list = :binary.bin_to_list(segment)

          assert segment_list
                 |> Enum.take_every(@mpegts_magic_period)
                 |> Enum.map(&(@mpegts_magicbyte == &1))
                 |> Enum.all?()

          ts + duration
      end

    assert_in_delta ed, returned_ed, 5
    assert ed <= returned_ed
  end

  test "Return the m4a segments of a given timestamp from a DASH stream." do
    # Same as above but sound (with DASH, vid and sound are usually different streams.).
  end
end
