defmodule VideoStream.SegmentInfo do
  @doc """
  Info of the segment acquired from an HLS or DASH playlist.
  """
  @type t() :: %{
          # Download url
          url: String.t(),
          # Sequence number
          seq: pos_integer(),
          # Time of the segment relative to the video
          vtime: float() | nil,
          # Wall clock time of the segment
          wctime: DateTime.t() | nil,
          duration: float(),
          # Expiry time of the url
          expiry: DateTime.t() | nil
          # May be included.
          # codec: binary()
        }
end
