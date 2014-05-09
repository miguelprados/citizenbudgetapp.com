class HerokuClient # avoid clash with heroku gem
  class << self
    # @return [Boolean] whether configuration variables are set
    def configured?
      ENV['HEROKU_API_KEY'] && ENV['HEROKU_APP']
    end

    # Lists the domain names associated to the Heroku app.
    # @return [Array<String>] a list of domain names
    def list_domains
      JSON.parse(client.get("/apps/#{ENV['HEROKU_APP']}/domains").body).map{|domain| domain['domain']}
    end

    # Adds a domain name to the Heroku app.
    # @param [String] domain a domain name
    # @return [Boolean] whether domain was added
    def add_domain(domain)
      JSON.parse(client.post("/apps/#{ENV['HEROKU_APP']}/domains", domain_name: {domain: domain}).body)['domain'] == domain
    end

    # Removes a domain name from the Heroku app.
    # @param [String] domain a domain name
    # @return [Boolean] whether domain was removed
    def remove_domain(domain)
      begin
        JSON.parse(client.delete("/apps/#{ENV['HEROKU_APP']}/domains/#{domain}").body) == {}
      rescue MultiJson::DecodeError
        false
      end
    end

  private

    # @return [Faraday::Connection] an HTTP client for the Heroku API
    def client
      Faraday.new 'https://api.heroku.com', headers: {'Accept' => 'application/json'} do |builder|
        builder.request :url_encoded
        builder.request :basic_auth, nil, ENV['HEROKU_API_KEY']
        builder.adapter :net_http
      end
    end
  end
end
