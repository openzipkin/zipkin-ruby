# Zipkin Ruby example 

**What's included in this example?**
- Outgoing requests tracing with Faraday.
- Sidekiq Worker tracing.
- Local Tracing.

To run this example, first change your directory into example and install
all dependencies

```bash
bundle install
```

To run the example with Sidekiq tracing, please run redis in the background
before hand:

```bash
redis-server
```

Start the web server and sidekiq worker
```
bundle exec rackup -p 3000
bundle exec sidekiq -C sidekiq_config.yml -r ./my_worker.rb
```

After everything is started, you may go to `localhost:3000` to perform some
requests and then `localhost:9411` (*or the port that you started Zipkin*) to
see these traces.
