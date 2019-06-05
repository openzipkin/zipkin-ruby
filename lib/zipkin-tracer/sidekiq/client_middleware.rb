module ZipkinTracer
  module Sidekiq
    class ClientMiddleware
      def call(_worker_class, job, _queue, _redis_pool = nil)
        if Thread.current[:trace_stack].present?
          job['trace_stack'] = Thread.current[:trace_stack].map(&:as_json)
          # job['trace_stack'] = Thread.current[:trace_stack].map { |trace| Marshal::dump(trace) }
        end

        yield
      end
    end
  end
end
