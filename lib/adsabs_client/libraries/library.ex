defmodule ADSABSClient.Libraries.Library do
  @moduledoc """
  Struct representing an ADS private library.
  """

  @type t :: %__MODULE__{
          id: String.t() | nil,
          name: String.t(),
          description: String.t(),
          num_documents: non_neg_integer(),
          date_created: String.t() | nil,
          date_last_modified: String.t() | nil,
          permission: String.t(),
          public: boolean(),
          owner: String.t() | nil,
          bibcodes: [String.t()]
        }

  defstruct id: nil,
            name: "",
            description: "",
            num_documents: 0,
            date_created: nil,
            date_last_modified: nil,
            permission: "owner",
            public: false,
            owner: nil,
            bibcodes: []

  @doc "Build from an ADS API library metadata map."
  @spec from_map(map()) :: t()
  def from_map(data) when is_map(data) do
    %__MODULE__{
      id: Map.get(data, "id"),
      name: Map.get(data, "name", ""),
      description: Map.get(data, "description", ""),
      num_documents: Map.get(data, "num_documents", 0),
      date_created: Map.get(data, "date_created"),
      date_last_modified: Map.get(data, "date_last_modified"),
      permission: Map.get(data, "permission", "owner"),
      public: Map.get(data, "public", false),
      owner: Map.get(data, "owner"),
      bibcodes: Map.get(data, "bibcodes", [])
    }
  end
end
