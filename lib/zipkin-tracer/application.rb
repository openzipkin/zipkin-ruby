module ZipkinTracer

  # Useful methods on the Application we are instrumenting
  class Application
    # If the request is not valid for this service, we do not what to trace it.
    def self.routable_request?(path_info, http_method)
      return true unless defined?(Rails) # If not running on a Rails app, we can't verify if it is invalid
      Rails.application.routes.recognize_path(path_info, method: http_method)
      true
    rescue ActionController::RoutingError
      false
    end

    def self.get_route(env)
      return nil unless defined?(Rails)
      stub_env = {
        "PATH_INFO" => env[ZipkinTracer::RackHandler::PATH_INFO],
        "REQUEST_METHOD" => env[ZipkinTracer::RackHandler::REQUEST_METHOD]
      }
      req = Rack::Request.new(stub_env)
      # Returns a string like /some/path/:id
      Rails.application.routes.router.recognize(req) do |route|
        return route.path.spec.to_s
      end
    rescue
      nil
    end

    def self.logger
      if defined?(Rails.logger) # If we happen to be inside a Rails app, use its logger
        Rails.logger
      else
        Logger.new(STDOUT)
      end
    end

    def self.config(app)
      if app.respond_to?(:config) && app.config.respond_to?(:zipkin_tracer)
        app.config.zipkin_tracer
      else
        {}
      end
    end
  end
end
