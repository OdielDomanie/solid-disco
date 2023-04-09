defmodule VideoStream.DashYT do
  alias VideoStream.SegmentInfo
  alias :fxml, as: Fxml
  require Logger
  @type xmlel :: Fxml.xmlel()

  @spec segmentinfos_hack_yt(binary(), {number(), number()}) :: [
          {:audio | :video | atom(), [SegmentInfo.t()]}
        ]
  @doc """
  Given an MPD string from a Youtube livestream, returns segment urls and infos.

  The result is not guareented to be a sub- over superset of the requested
  interval.
  """
  def segmentinfos_hack_yt(mpd_string, st_ed) do
    mpd = :fxml_stream.parse_element(mpd_string)

    # Assume each segment has the same duration.
    seg_dur = calc_avg_seg_dur(mpd)

    mpd
    # Get one best audio and one best video repr
    |> get_best_repr()
    # Get the url  of the last segment of each.
    |> Enum.map(fn {type, repr} -> {type, get_last_segment_url(repr)} end)
    # Calculate the segment urls needed to cover the st_ed interval,
    # get a list of segment infos, for each adapt_set.
    # This is an approximation that can be assumed accurate enough,
    # and a hack. Whether the hack can currently work can be verified by using
    # --live-from-start option with yt-dlp.
    |> Enum.map(fn {type, last_seg_url} ->
      {type, calc_segment_urls(last_seg_url, st_ed, seg_dur, mpd)}
    end)
  end

  @spec get_best_repr(xmlel, any()) :: list({atom, xmlel()})
  # Given a strategy (only one strat now),
  # get the best audio and video representations.
  defp get_best_repr(mpd, _strat \\ :best_mp4) do
    # For every adaptation set (audio, video, cc, etc.)
    for adapt_set <-
          mpd
          |> Fxml.get_subtag("Period")
          |> Fxml.get_subtags("AdaptationSet") do
      case Fxml.get_tag_attr_s("mimeType", adapt_set) do
        "audio/mp4" ->
          # Get the mp4a codec with the highest bandwidth.
          repr =
            adapt_set
            |> Fxml.get_subtags("Representation")
            |> Enum.filter(fn repr ->
              Fxml.get_tag_attr_s("codecs", repr) |> String.starts_with?("mp4a")
            end)
            |> Enum.max_by(fn repr ->
              Fxml.get_tag_attr_s("bandwidth", repr) |> String.to_integer()
            end)

          {:audio, repr}

        "video/mp4" ->
          # Get the avc codec with the best of specified settings.
          repr =
            adapt_set
            |> Fxml.get_subtags("Representation")
            |> Enum.filter(fn repr ->
              Fxml.get_tag_attr_s("codecs", repr) |> String.starts_with?("avc1")
            end)
            |> Enum.max_by(fn repr ->
              for attr <- ["width", "height", "frameRate", "bandwidth", "id"] do
                Fxml.get_tag_attr_s(attr, repr) |> String.to_integer()
              end
            end)

          {:video, repr}

        other ->
          # Dont care, set null so we can filter it.
          Logger.debug("Found other adaptation set #{other}")
          nil
      end
    end
    # Remove the "dont care" ones.
    |> Enum.filter(& &1)
  end

  @spec get_last_segment_url(xmlel()) :: binary()
  defp get_last_segment_url(repr) do
    base_url = Fxml.get_subtag_cdata(repr, "BaseURL")

    last_segment =
      repr |> Fxml.get_subtag("SegmentList") |> Fxml.get_subtags("SegmentURL") |> List.last()

    base_url <> Fxml.get_tag_attr_s("media", last_segment)
  end

  @spec calc_avg_seg_dur(xmlel()) :: number()
  defp calc_avg_seg_dur(mpd) do
    # List of segment durations.
    segment_list = mpd |> Fxml.get_subtag("Period") |> Fxml.get_subtag("SegmentList")

    # Divide durations by timescale to get seconds.
    timescale = Fxml.get_tag_attr_s("timescale", segment_list) |> String.to_integer()

    # Get durations
    durations = segment_list |> Fxml.get_subtag("SegmentTimeline") |> Fxml.get_subtags("S")
    n = length(durations)
    # Sum to durations
    sum =
      durations
      |> Enum.map(&Fxml.get_tag_attr_s("d", &1))
      |> Enum.map(&String.to_integer/1)
      |> Enum.sum()

    # Return average and convert to seconds.
    sum / n / timescale
  end

  @spec calc_segment_urls(binary(), {number(), number()}, number(), xmlel()) ::
          list(SegmentInfo.t())
  defp calc_segment_urls(last_segment_url, {st, ed}, seg_dur, _mpd) do
    # Divide the segment url into 3 groups, the middle one is the seq number.
    seg_match = ~r/(.*\/sq\/)(?'seg_no'[0-9]*)(\/.*)/
    [_, url1, last_seg_no, _url3] = Regex.run(seg_match, last_segment_url)

    # Appearently the sequence number is uint32
    st_seg = floor(st / seg_dur) |> Integer.mod(2 ** 32)
    # Ending sequence no can't be larger than the last one.
    ed_seg = floor(ed / seg_dur) |> Integer.mod(2 ** 32) |> min(String.to_integer(last_seg_no))

    # Sanity check
    if ed_seg < st_seg or ed_seg - st_seg > 10_000 do
      raise "Bad st_seg and ed_seg #{inspect({st_seg, ed_seg})}"
    end

    # For every sequence number
    for seg_no <- st_seg..ed_seg do
      # The YT hack to get the url of an arbitrary sequence.
      # <> url3
      calc_url = url1 <> Integer.to_string(seg_no)

      %{
        # Download url
        url: calc_url,
        # Sequence number
        seq: seg_no,
        # Time of the segment relative to the video
        vtime: seg_no * seg_dur,
        # Wall clock time of the segment.
        # Not precisely known, so rather leave it empty.
        wctime: nil,
        # This may be off by milliseconds, so trust the downstreams algos
        # are fuzzy enough to deal with small inconsistencies.
        duration: seg_dur,
        # Expiry time of the url
        # We can guess (120 hours), but so can downstream, thus leave it empty.
        # We are actually given this by `timeShiftBufferDepth`,
        # but it is false I assume.
        expiry: nil
      }
    end
  end
end
