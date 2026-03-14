defmodule ADSABSClient.FeedbackTest do
  @moduledoc false
  use ADSABSClient.Test.MockCase, async: true

  alias ADSABSClient.{Error, Feedback}
  alias ADSABSClient.Test.Fixtures

  describe "submit/1" do
    test "posts feedback with all required fields" do
      expect(ADSABSClient.HTTP.Mock, :post, fn "/feedback/userfeedback", body, _opts ->
        assert body["name"] == "Dr. Smith"
        assert body["email"] == "smith@example.com"
        assert body["subject"] == "Missing author"
        assert body["body"] == "Author X is missing."
        Fixtures.ok_response(%{"success" => true})
      end)

      {:ok, result} =
        Feedback.submit(
          name: "Dr. Smith",
          email: "smith@example.com",
          subject: "Missing author",
          body: "Author X is missing."
        )

      assert result["success"] == true
    end

    test "defaults origin to 'adsabs_client'" do
      expect(ADSABSClient.HTTP.Mock, :post, fn "/feedback/userfeedback", body, _opts ->
        assert body["origin"] == "adsabs_client"
        Fixtures.ok_response(%{})
      end)

      {:ok, _} =
        Feedback.submit(
          name: "Test",
          email: "test@test.com",
          subject: "Test",
          body: "Test"
        )
    end

    test "uses custom origin when provided" do
      expect(ADSABSClient.HTTP.Mock, :post, fn "/feedback/userfeedback", body, _opts ->
        assert body["origin"] == "my_app"
        Fixtures.ok_response(%{})
      end)

      {:ok, _} =
        Feedback.submit(
          name: "Test",
          email: "test@test.com",
          subject: "Test",
          body: "Test",
          origin: "my_app"
        )
    end

    test "includes bibcode when provided" do
      expect(ADSABSClient.HTTP.Mock, :post, fn "/feedback/userfeedback", body, _opts ->
        assert body["bibcode"] == "2016PhRvL.116f1102A"
        Fixtures.ok_response(%{})
      end)

      {:ok, _} =
        Feedback.submit(
          name: "Test",
          email: "test@test.com",
          subject: "Wrong data",
          body: "The data for this paper is wrong.",
          bibcode: "2016PhRvL.116f1102A"
        )
    end

    test "returns validation error when name is missing" do
      {:error, error} =
        Feedback.submit(
          email: "test@test.com",
          subject: "Test",
          body: "Test"
        )

      assert error.type == :validation_error
      assert error.message =~ "name"
    end

    test "returns validation error when email is missing" do
      {:error, error} =
        Feedback.submit(
          name: "Test",
          subject: "Test",
          body: "Test"
        )

      assert error.type == :validation_error
      assert error.message =~ "email"
    end

    test "returns validation error when multiple required fields are missing" do
      {:error, error} = Feedback.submit([])
      assert error.type == :validation_error
    end
  end
end
