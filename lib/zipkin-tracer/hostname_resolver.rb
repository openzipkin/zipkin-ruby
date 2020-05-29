require 'resolv'

module ZipkinTracer
  # Resolves hostnames in the endpoints of the spans.
  # Resolving hostnames is a very expensive operation. We want to store them raw in the main thread
  # and resolve them in a different thread where we do not affect execution times.
  class HostnameResolver
    def spans_with_ips(spans, ip_format)
      hosts = unique_hosts(spans)
      resolved_hosts = resolve(hosts, ip_format)

      each_endpoint(spans) do |endpoint|
        hostname = endpoint.ipv4
        next unless hostname
        next if resolved_ip_address?(hostname.to_s)

        endpoint.ipv4 = resolved_hosts[hostname]
      end
    end

    private

    LOCALHOST = '127.0.0.1'.freeze
    LOCALHOST_I32 = 0x7f000001
    MAX_I32 = ((2 ** 31) - 1)
    MASK = (2 ** 32) - 1
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
    def unique_hosts(spans)
      hosts = []
      each_endpoint(spans) do |endpoint|
        hosts.push(endpoint)
      end
      hosts.uniq
    end

    def resolve(hosts, ip_format)
      hosts.each_with_object({}) do |host, host_map|
        hostname = host.ipv4  # This field has been temporarly used to store the hostname.
        host_map[hostname] = host_to_format(hostname, ip_format) if hostname
      end
    end

    def host_to_format(hostname, ip_format)
      begin
        ip_format == :string ? Socket.getaddrinfo(hostname, nil, :INET).first[IP_FIELD] : host_to_i32(hostname)
      rescue
        ip_format == :string ? LOCALHOST : LOCALHOST_I32
      end
    end

    def host_to_i32(host)
      unsigned_i32 = Socket.getaddrinfo(host, nil)[0][3].split(".").map do |i|
        i.to_i
      end.inject(0) { |a,e| (a << 8) + e }

      signed_i32 = if unsigned_i32 > MAX_I32
        -1 * ((unsigned_i32 ^ MASK) + 1)
      else
        unsigned_i32
      end

      signed_i32
    end
  end
end
