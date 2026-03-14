defmodule ADSABSClient.ExportTest do
  @moduledoc false
  use ADSABSClient.Test.MockCase, async: true

  alias ADSABSClient.{Error, Export}
  alias ADSABSClient.Test.Fixtures

  @bibcodes ["2016PhRvL.116f1102A", "2019ApJ...882L..24A"]

  describe "bibtex/2" do
    test "returns bibtex string on success" do
      expect(ADSABSClient.HTTP.Mock, :post, fn "/export/bibtex", _body, _opts ->
        Fixtures.ok_response(Fixtures.export_response_body("bibtex"))
      end)

      {:ok, result} = Export.bibtex(@bibcodes)
      assert is_binary(result)
      assert result =~ "@article"
    end

    test "returns validation error for empty bibcodes" do
      {:error, error} = Export.bibtex([])
      assert error.type == :validation_error
    end
  end

  for format <- ~w(endnote ris aastex mnras icarus soph refabsxml rss)a do
    format_str = to_string(format)

    test "#{format_str}/2 posts to correct endpoint" do
      format_atom = unquote(format)
      format_name = unquote(format_str)

      expect(ADSABSClient.HTTP.Mock, :post, fn path, _body, _opts ->
        assert path == "/export/#{format_name}"
        Fixtures.ok_response(%{"export" => "some #{format_name} content"})
      end)

      {:ok, result} = apply(Export, format_atom, [["2016PhRvL.116f1102A"]])
      assert is_binary(result)
    end
  end

  describe "custom/3" do
    test "posts custom format template to /export/custom" do
      expect(ADSABSClient.HTTP.Mock, :post, fn "/export/custom", body, _opts ->
        assert Map.has_key?(body, "format")
        Fixtures.ok_response(%{"export" => "custom result"})
      end)

      {:ok, result} = Export.custom(@bibcodes, "%T %A %Y")
      assert result == "custom result"
    end

    test "returns validation error for empty bibcodes" do
      {:error, error} = Export.custom([], "%T")
      assert error.type == :validation_error
    end
  end
end
