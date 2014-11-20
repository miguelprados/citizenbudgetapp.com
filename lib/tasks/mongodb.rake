namespace :mongodb do
  desc 'Copy a development database to production'
  task push: :environment do
    if Rails.env.development?
      puts <<-END
 !    WARNING: Destructive Action
 !    Data in the #{ENV['APP']} app will be overwritten and will not be recoverable.
 !    To proceed, type "nogoingback"
END
      if STDIN.gets == "nogoingback\n"
        uri = URI.parse `heroku config:get MONGOLAB_URI --app #{ENV['APP']}`.chomp
        puts `mongodump -h localhost -d citizen_budget_development -o dump-dir`.chomp
        puts `mongorestore -h #{uri.host}:#{uri.port} -d #{uri.path.sub '/', ''} -u #{uri.user} -p #{uri.password} dump-dir/citizen_budget_development`.chomp
      else
        puts 'Confirmation did not match "nogoingback". Aborted.'
      end
    else
      puts 'rake mongodb:push can only be run in development'
    end
  end

  desc 'Copy a production database to development'
  task pull: :environment do
    if Rails.env.development?
      uri = URI.parse `heroku config:get MONGOLAB_URI --app #{ENV['APP']}`.chomp
      puts `mongodump -h #{uri.host}:#{uri.port} -d #{uri.path.sub '/', ''} -u #{uri.user} -p #{uri.password} -c questionnaires -o dump-dir`.chomp
      puts `mongodump -h #{uri.host}:#{uri.port} -d #{uri.path.sub '/', ''} -u #{uri.user} -p #{uri.password} -c responses -o dump-dir`.chomp
      puts `mongorestore -h localhost -d citizen_budget_development --drop dump-dir#{uri.path}`.chomp
    else
      puts 'rake mongodb:pull can only be run in development'
    end
  end

  desc 'Download a production database'
  task download: :environment do
    if Rails.env.development?
      uri = URI.parse `heroku config:get MONGOLAB_URI --app #{ENV['APP']}`.chomp
      puts `mongodump -h #{uri.host}:#{uri.port} -d #{uri.path.sub '/', ''} -u #{uri.user} -p #{uri.password} -c questionnaires -o dump-dir`.chomp
      puts `mongodump -h #{uri.host}:#{uri.port} -d #{uri.path.sub '/', ''} -u #{uri.user} -p #{uri.password} -c responses -o dump-dir`.chomp
    else
      puts 'rake mongodb:download can only be run in development'
    end
  end
end
