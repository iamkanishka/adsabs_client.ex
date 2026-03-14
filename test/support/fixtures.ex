defmodule ADSABSClient.Test.Fixtures do
  @moduledoc "Shared test fixtures for ADSABSClient tests."

  @rate_limit_headers [
    {"x-ratelimit-limit", "5000"},
    {"x-ratelimit-remaining", "4980"},
    {"x-ratelimit-reset", "1735689600"},
    {"content-type", "application/json"}
  ]

  def rate_limit_headers, do: @rate_limit_headers

  def search_response_body(overrides \\ %{}) do
    Map.merge(
      %{
        "responseHeader" => %{"QTime" => 12, "status" => 0},
        "response" => %{
          "numFound" => 3,
          "start" => 0,
          "docs" => [
            %{
              "bibcode" => "2016PhRvL.116f1102A",
              "title" => ["Observation of Gravitational Waves from a Binary Black Hole Merger"],
              "author" => ["Abbott, B. P.", "Abbott, R."],
              "year" => "2016",
              "citation_count" => 8500
            },
            %{
              "bibcode" => "2019ApJ...882L..24A",
              "title" => ["Multi-messenger Observations of a Binary Neutron Star Merger"],
              "author" => ["Abbott, B. P."],
              "year" => "2019",
              "citation_count" => 3200
            },
            %{
              "bibcode" => "2020A&A...641A...1P",
              "title" => ["Planck 2018 results"],
              "author" => ["Planck Collaboration"],
              "year" => "2020",
              "citation_count" => 2100
            }
          ]
        }
      },
      overrides
    )
  end

  def empty_search_response_body do
    %{
      "responseHeader" => %{"QTime" => 5, "status" => 0},
      "response" => %{"numFound" => 0, "start" => 0, "docs" => []}
    }
  end

  def metrics_response_body do
    %{
      "basic stats" => %{
        "number of papers" => 3,
        "total citations" => 13_800,
        "normalized citations" => 4600.0
      },
      "citation stats" => %{
        "total number of citations" => 13_800,
        "average number of citations" => 4600.0,
        "median number of citations" => 3200.0,
        "total number of refereed citations" => 12_000
      },
      "indicators" => %{
        "h" => 3,
        "g" => 3,
        "m" => 1.0,
        "i10" => 3,
        "i100" => 1,
        "tori" => 12.5,
        "riq" => 150,
        "read10" => 25.0
      },
      "histograms" => %{},
      "time series" => %{},
      "skipped bibcodes" => []
    }
  end

  def export_response_body(format \\ "bibtex") do
    %{
      "export" => """
      @article{2016PhRvL.116f1102A,
        author = {Abbott, B. P. and Abbott, R.},
        title = {Observation of Gravitational Waves},
        journal = {Physical Review Letters},
        year = {2016},
        volume = {116},
        format = #{format}
      }
      """
    }
  end

  def library_list_response_body do
    %{
      "libraries" => [
        %{
          "id" => "abc123",
          "name" => "My Papers",
          "description" => "Papers I like",
          "num_documents" => 5,
          "date_created" => "2024-01-15T00:00:00",
          "date_last_modified" => "2024-03-10T00:00:00",
          "permission" => "owner",
          "public" => false,
          "owner" => "user@example.com"
        }
      ]
    }
  end

  def library_get_response_body do
    %{
      "metadata" => %{
        "name" => "My Papers",
        "description" => "Papers I like",
        "num_documents" => 2,
        "date_created" => "2024-01-15T00:00:00",
        "date_last_modified" => "2024-03-10T00:00:00",
        "permission" => "owner",
        "public" => false,
        "owner" => "user@example.com"
      },
      "documents" => ["2016PhRvL.116f1102A", "2019ApJ...882L..24A"],
      "solr" => %{},
      "metadata" => %{}
    }
  end

  def ok_response(body, headers \\ nil) do
    {:ok,
     %{
       status: 200,
       headers: headers || @rate_limit_headers,
       body: body
     }}
  end

  def error_response(status, message \\ nil) do
    {:ok,
     %{
       status: status,
       headers: @rate_limit_headers,
       body: %{"error" => message || "Error #{status}"}
     }}
  end

  def rate_limited_response(retry_after \\ 60) do
    {:ok,
     %{
       status: 429,
       headers: [{"retry-after", "#{retry_after}"} | @rate_limit_headers],
       body: %{"error" => "Too Many Requests"}
     }}
  end
end
