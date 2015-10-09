require_relative './spec_helper.rb'

describe EDSApi::ConnectionHandler do
  
  before :all do
    @testConnection = EDSApi::ConnectionHandler.new
    @testConnection.uid_init('edsapi','beta2012','demo').uid_authenticate(:json)
    @session_key = @testConnection.create_session
  end
      
  it "should initialize a new ConnectionHandler object" do
    @testConnection.should be_an_instance_of EDSApi::ConnectionHandler    
  end
  
  it "should toss an error message if uid authentication fails" do
    connection = EDSApi::ConnectionHandler.new
    results = connection.uid_init('edsapi','blah','demo').uid_authenticate(:json).to_hash
    connection.auth_token.should be_nil
    results["Reason"].should_not be_empty
    #results["Reason"].should == "Invalid Credentials."
  end
  
  it "should authenticate to the API using UID method and return an auth token" do
    # uncomment the following line to see the auth_token
    # puts connection.auth_token
    @testConnection.auth_token.should_not be_empty
  end

  it "should return a valid XML document using the INFO method" do
    results = @testConnection.info(@session_key, :json).to_hash
    results["AvailableSearchCriteria"].keys.should_not be_empty
  end

end
