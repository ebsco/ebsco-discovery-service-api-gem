require 'ebsco-discovery-service-api'

class EDAPITest < Minitest::Test
  def test_connect
    
    # creates EDS API connection object, initializing it with application login credentials
    connection = EDSApi::ConnectionHandler.new(2)
    connection.uid_init("ericfrier", "password", "profile", "n")
    
    assert_equal "hello world",
      Hola.hi("english")
  end
end