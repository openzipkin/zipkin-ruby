module ZipkinTracer
  module Sidekiq
    class Middleware
      def initialize(app, config = nil)
        @app = app
        @config = Config.new(app, config).freeze
        @tracer = TracerFactory.new.tracer(@config)
      end

      def sample?
        rand < @config.sample_rate
      end

      def call(worker, item, _queue)
        id = Trace.generate_id
        trace_id = Trace::TraceId.new(id, nil, id, sample?, ::Trace::Flags::EMPTY)

        result = nil
        klass = item["wrapped".freeze] || worker.class.to_s
        ::Trace.with_trace_id(trace_id) do
          if sample?
            @tracer.with_new_span(trace_id, klass) do |span|
              span.record("mr")
              result = yield
              span.record("ms")
            end
          else
            result = yield
          end
        end
        ::Trace.tracer.flush! if ::Trace.tracer.respond_to?(:flush!)
        result
      end
    end
  end
end
