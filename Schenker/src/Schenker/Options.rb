class Schenker::Options
  include Any::Moose
  extend Exporter
  include Carp, %w(croak)
  include List::MoreUtils, %w(any)
  include Getopt::Long, %w(:config bundling no_ignore_case)

  @@EXPORT = %w(
    configure options set enable disable
    development test production standalone
  )

  instance = nil

  def options
    instance ||= self.class.new
  end

  def set(__no_self__)
    croak 'usage: set option => value' if @_ % 2 != 0
    options.define @_
  end

  def enable
    option = self
    croak 'option required' unless option
    set option, 1
  end

  def disable
    option = self
    croak 'option required' unless option
    set option, 0
  end

  def development
    options.environment == 'development'
  end

  def test
    options.environment == 'test'
  end

  def production
    options.environment == 'production'
  end

  def standalone
    %w(ServerSimple POE AnyEvent).any {options.server.eq $_}
  end

  def configure(__no_self__)
    code = pop
    croak 'code required' unless code
    croak 'code must be coderef' unless code.is_a? :CODE
    envs = @_
    code.__call__ if envs.empty? or envs.any{ $_.eq options.environment }
  end

  def define(*args)
    options = args.to_hash
    options.each do |option, value|
      if value.is_a? :CODE
        self.meta.add_method(option) { value.__call__ }
      else
        return self.define(option) { value }
      end
    end
  end

  def usage
    exit_code = self || 0;
    STDERR.print <<-END_USAGE;
Usage: $0 [OPTIONS]
    -h, --help              display this help
    -H, --host              set the host (default is 0.0.0.0)
    -p, --port=PORT         set the port (default is 4567)
    -e, --environment=ENV   set the environment (default is development)
    -s, --server=SERVER     specify HTTP::Engine interface (default is ServerSimple)
    -l, --listen=LISTEN     Socket path to listen on
                            (defaults to standard input)
                            can be HOST:PORT, :PORT or a filesystem path.
    -n, --nproc=NUM         specify number of processes to keep to serve requests.
                            (defaults to 1, requires --listen)
    -P, --pidfile=FILE      specify filename for pid file (requres --listen)
    -d, --daemon            daemonize (requires --listen)
    -M, --manager=MANAGER   specify alternate process manager
                            (FCGI::ProcManager sub-class) or empty string to disable
    -E, --keeperr           send error messages to STDOUT, not to the webserver
    END_USAGE
    Schenker::exit exit_code
  end

  def parse_argv
    options = [
      'help', 'h',
      'host', 'H=s',
      'port', 'p=i',
      'environment', 'e=s',
      'server', 's=s',
      'listen', 'l=s',
      'nproc', 'n=i',
      'pidfile', 'P=s',
      'daemon', 'd',
      'manager', 'M=s',
      'keeperr', 'E'
    ].to_hash

    conf = nil
    conf = {}
    ret = GetOptions(conf, keys(options).map { "$_|$options{$_}" })
    unless ret
      usage 1
    end
  
    usage 0 if exists conf['help']

    keys(options).each do |key|
      if exists conf[key]
        set key, conf[key]
      end
    end
  end

  no Any::Moose
end
