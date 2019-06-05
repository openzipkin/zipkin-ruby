module ZipkinTracer
  module Sidekiq
    class ServerMiddleware
      attr_reader :config, :tracer, :traceable_workers

      def initialize(config)
        @config = Config.new(nil, config).freeze
        @tracer = TracerFactory.new.tracer(@config)
        @traceable_workers = config.fetch(:traceable_workers, [])
      end

      def call(worker, job, queue, &block)
        return block.call unless traceable_worker?(worker)

        set_trace_stack(job.fetch('trace_stack', []))

        trace(worker, job, queue, &block)
      end

      private

      def traceable_worker?(worker)
        traceable_workers.include?(:all) || traceable_workers.include?(worker_name(worker))
      end

      def set_trace_stack(trace_stack)
        # Thread.current[:trace_stack] = trace_stack.map { |trace| Marshal::load(trace) }
        Thread.current[:trace_stack] =
          trace_stack.map do |trace|
            Trace::TraceId.new(
              trace.dig('trace_id', 'value'),
              trace.dig('parent_id', 'value'),
              trace.dig('span_id', 'value'),
              trace.dig('sampled'),
              trace.dig('flags'),
              trace.dig('shared'),
            )
          end
      end

      def trace(worker, job, queue, &block)
        trace_id = TraceGenerator.new.next_trace_id
        span_name = worker_name(worker)

        result = TraceContainer.with_trace_id(trace_id) do
          if trace_id.sampled?
            tracer.with_new_span(trace_id, span_name) do
              result = block.call
            end
          else
            result = block.call
          end
        end

        tracer.flush!
        result
      end

      def worker_name(worker)
        worker.class.to_s.to_sym
      end
    end
  end
end
