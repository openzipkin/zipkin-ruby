require 'resolv'

module ZipkinTracer
  # Resolves hostnames in the endpoints of the spans.
  # Resolving hostnames is a very expensive operation. We want to store them raw in the main thread
  # and resolve them in a different thread where we do not affect execution times.
  class HostnameResolver
    def spans_with_ips(spans)
      host_to_ip = hosts_to_ipv4(spans)

      each_endpoint(spans) do |endpoint|
        hostname = endpoint.ipv4
        unless resolved_ip_address?(hostname.to_s)
          endpoint.ipv4 = host_to_ip[hostname]
        end
      end
    end

    private
    LOCALHOST = '127.0.0.1'.freeze
    LOCALHOST_I32 = 0x7f000001.freeze
    IP_FIELD = 3

    def resolved_ip_address?(ip_string)
      # When the ip_format is string, we will match with one of these two regexp
      # When the ip_format is :i32 (used by kafka), we just check the string is a number
      !!(ip_string =~ Regexp.union(Resolv::IPv4::Regex, Resolv::IPv6::Regex)) ||
        ip_string.to_i.to_s == ip_string
    end

    def each_endpoint(spans, &block)
      spans.each do |span|
        [span.local_endpoint, span.remote_endpoint].each do |endpoint|
          yield endpoint if endpoint
        end
      end
    end

    # Using this to resolve only once per host
    def hosts_to_ipv4(spans)
      hosts = []
      each_endpoint(spans) do |endpoint|
        hosts.push(endpoint)
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
      begin
        ip_format == :string ? Socket.getaddrinfo(hostname, nil, :INET).first[IP_FIELD] : Trace::Endpoint.host_to_i32(hostname)
      rescue
        ip_format == :string ? LOCALHOST : LOCALHOST_I32
      end
    end
  end

end
