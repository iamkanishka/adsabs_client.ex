defmodule ADSABSClient.Feedback do
  @moduledoc """
  ADS User Feedback API — `/feedback/userfeedback`.

  Allows submitting feedback about ADS records, such as reporting incorrect
  abstracts, wrong authors, or missing data.

  ## Example

      {:ok, _} = ADSABSClient.Feedback.submit(
        name: "Jane Astronomer",
        email: "jane@example.com",
        subject: "Missing author",
        body: "The paper 2016PhRvL.116f1102A is missing co-author X.",
        origin: "user_submission"
      )
  """

  alias ADSABSClient.{Error, HTTP}

  @doc """
  Submit user feedback to ADS.

  ## Required Options

  - `:name` — submitter's name
  - `:email` — submitter's email address
  - `:subject` — feedback subject
  - `:body` — feedback message body

  ## Optional Options

  - `:origin` — feedback origin tag (default: `"adsabs_client"`)
  - `:bibcode` — related bibcode if feedback is about a specific paper

  ## Example

      {:ok, result} = ADSABSClient.Feedback.submit(
        name: "Researcher",
        email: "researcher@institution.edu",
        subject: "Wrong affiliation",
        body: "The affiliation for author X is incorrect.",
        bibcode: "2016PhRvL.116f1102A"
      )
  """
  @spec submit(keyword()) :: {:ok, map()} | {:error, ADSABSClient.Error.t()}
  def submit(opts \\ []) do
    required = [:name, :email, :subject, :body]
    missing = Enum.reject(required, &Keyword.has_key?(opts, &1))

    if Enum.empty?(missing) do
      body =
        %{
          "name" => Keyword.fetch!(opts, :name),
          "email" => Keyword.fetch!(opts, :email),
          "subject" => Keyword.fetch!(opts, :subject),
          "body" => Keyword.fetch!(opts, :body),
          "origin" => Keyword.get(opts, :origin, "adsabs_client")
        }
        |> maybe_put("bibcode", opts[:bibcode])

      with {:ok, resp} <- HTTP.client().post("/feedback/userfeedback", body, []) do
        {:ok, resp.body}
      end
    else
      {:error, Error.validation_error("Feedback.submit is missing required keys: #{Enum.join(missing, ", ")}")}
    end
  end

  # --- Private ---

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
