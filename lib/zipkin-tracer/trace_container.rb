module ZipkinTracer
  # This class manages a thread-unique container with the stack of traceIds
  # This stack may grow if for instance the current process creates local components inside local components
  class TraceContainer
    class << self
      def with_trace_id(trace_id, &_block)
        container.push(trace_id)
        yield
      ensure
        container.pop
      end

      def current
        container.last
      end

      def tracing_information_set?
        !container.empty?
      end

      # DO NOT USE unless you ABSOLUTELY know what you are doing.
      def cleanup!
        Thread.current[TRACE_STACK] = []
      end

      private

      def container
        Thread.current[TRACE_STACK] ||= []
      end
      TRACE_STACK = :trace_stack
    end
  end
end
