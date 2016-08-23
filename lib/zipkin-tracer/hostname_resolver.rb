module ZipkinTracer
  # Resolves hostnames in the endpoints of the annotations.
  # Resolving hostnames is a very expensive operation. We want to store them raw in the main thread
  # and resolve them in a different thread where we do not affect execution times.
  class HostnameResolver
    def spans_with_ips(spans)
      host_to_ip = hosts_to_ipv4(spans)

      each_annotation(spans) do |annotation|
        hostname = annotation.host.ipv4
        annotation.host.ipv4 = host_to_ip[hostname]
      end
    end

    private
    LOCALHOST = '127.0.0.1'.freeze
    LOCALHOST_I32 = 0x7f000001.freeze
    IP_FIELD = 3

    def each_annotation(spans, &block)
      spans.each do |span|
        span.annotations.each do |annotation|
          yield annotation
        end
        span.binary_annotations.each do |annotation|
          yield annotation
        end
      end
    end

    # Annotations come in pairs like CS/CR, SS/SR.
    # Each annnotation has a hostname so we, for sure, will have the same host multiple times.
    # Using this to resolve only once per host
    def hosts_to_ipv4(spans)
      hosts = []
      each_annotation(spans) do |annotation|
        hosts.push(annotation.host)
      end
      hosts.uniq!
      resolve(hosts)
    end

    def resolve(hosts)
      hosts.inject({}) do |host_map, host|
        hostname = host.ipv4  # This field has been temporarly used to store the hostname.
        ip_format = host.ip_format
        host_map[hostname]  = host_to_ip(hostname, ip_format)
        host_map
      end
    end

    def host_to_ip(hostname, ip_format)
      ipv4 = begin
        ip_format == :string ? Socket.getaddrinfo(hostname, nil, :INET).first[IP_FIELD] : Trace::Endpoint.host_to_i32(hostname)
      rescue
        ip_format == :string ? LOCALHOST : LOCALHOST_I32
      end
    end
  end

end
