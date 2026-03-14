ExUnit.start(exclude: [:integration])

# Define the Mox mock for the HTTP client
Mox.defmock(ADSABSClient.HTTP.Mock, for: ADSABSClient.HTTP.Behaviour)
