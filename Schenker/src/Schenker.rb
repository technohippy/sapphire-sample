class Schenker < Exporter
  include 5.00800
  include Any::Moose
  include Carp, %w(croak)
  include Scalar::Util, %w(blessed)
  include Path::Class, %w(file dir)
  include Encode, %w(decode)
  include URI::Escape, %w(uri_unescape)
  include Schenker::Router
  include Schenker::Engine
  include Schenker::Templates
  include Schenker::Halt
  include Schenker::Options
  include Schenker::Error
  include Schenker::NotFound
  include Schenker::Helpers

  @@VERSION = '0.01';

  @@App = nil
  @@AppFile = nil
  @@Initialized = nil
  @@Exited = nil
  @@Filters = []
  @@Errors = [].to_hash

  @@EXPORT = %w(
    helpers Before error not_found define_error
    request response stash session status param params redirect
    back body content_type etag headers last_modified
    attachment send_file
  )
  @@EXPORT.push Schenker::Engine::EXPORT 
  @@EXPORT.push Schenker::Router::EXPORT 
  @@EXPORT.push Schenker::Templates::EXPORT 
  @@EXPORT.push Schenker::Halt::EXPORT 
  @@EXPORT.push Schenker::Options::EXPORT 
  @@EXPORT.push Schenker::Helpers::EXPORT

  def import(__no_self__)
    pkg, file = caller
    croak <<-END_MSG if defined? pkg and pkg == 'main'
Can't use Schenker in the 'main' package.
Please use Schenker in your package.
    END_MSG

    unless defined? @@App
      @@App = pkg
      @@AppFile = file
    end

    self.class.export_to_level 1, @_
    any_moose.import into_level: 1
  end

  def unimport
    caller = caller()
    any_moose.unimport
    no strict 'refs'
    @@EXPORT.each do |method|
      delete ("#{caller}::".to_deref)[method]
    end
  end

  def request
    croak 'cannot call request in not running server.'
  end

  def response
    croak 'cannot call response in not running server.'
  end

  def stash
    croak 'cannot call stash in not running server.'
  end

  def make_stash(*args)
    stash = self
    ->{
      arg_size = scalar args
      if arg_size == 0
        stash
      elsif arg_size == 1
        stash[args[0]]
      elsif arg_size % 2 == 0
        args_hash = args.to_hash
        args_hash.each do |key, val|
          stash[key] = val
        end
      else
        croak 'usage: stash key or stash key => val;'
      end
    }
  end

  def session
    croak 'cannot call session in not running server.'
  end

  def make_session
    if options.sessions
      ->{request.session}
    else
      ->{croak "session is disabled. To enable session, set 'sessions' option true."}
    end
  end

  def helpers(__no_self__, *args)
    croak 'usage: helpers name => code' unless scalar(args) % 2 == 0;
    helpers = args.to_hash
    helpers.each do |name, sub|
      @@App.meta.add_method name, sub
    end
  end

  def Before
    code = self 
    croak 'code required' unless code
    croak 'code must be coderef' unless ref(code) == 'CODE'
    push @@Filters, code
  end

  def error(__no_self__, *args)
    code = args.pop
    croak 'code required' unless code
    klass = args.shift || 'Schenker::Error'
    @@Errors[klass] = code
  end

  def not_found(__no_self__, *args)
    error 'Schenker::NotFound', args
  end

  def error_in_request(__no_self__, *args)
    body = args.pop
    code = args.shift || 500
    halt code, body
  end

  def not_found_in_request
    body = self
    halt 404, body
  end

  def status
    status = self
    response.status status if defined? status
    response.status
  end

  def param(__no_self__)
    request.param @_
  end

  def params(__no_self__)
    request.params @_
  end

  def parse_nested_query
    new_params = {}
    param.each do |full_key|
      this_param = new_params
      value = params[full_key]
      split_keys = full_key.split /\]\[|\]|\[/
      (0..scalar(split_keys)).each do |index|
        break if split_keys.size == index + 1
        this_param[split_keys[index]] ||= {}
        this_param = this_param[split_keys[index]]
      end
      this_param[split_key[-1]] = value
    end
    params new_params
  end

  def headers(__no_self__)
    @_ ? response.header(@_) : response.headers
  end

  def redirect
    uri = self
    status 302
    headers 'Location', uri
    halt @_
  end

  def back
    request.referer
  end

  def body
    if self
      response.body self
      response.content_length bytes__length(self)
    end
    response.body
  end

  def content_type
    response.content_type self if self
    response.content_type
  end

  def etag
    etag = self
    croak 'ETag required' unless etag
    headers 'ETag', etag
  end

  def last_modified
    time = self
    headers.last_modified time if time
    headers.last_modified time
  end

  def define_error(code)
    name = self
    croak 'name required' unless name

    any_moose('::Meta::Class').create name, 'superclasses', ['Schenker::Error'], 'cache', 1
    return unless code;
    croak 'code must be coderef' unless ref(code) == 'CODE'
    error name, code
  end

  #sub attachment # TODO
  #sub send_file  # TODO

  def decode_args
    :'%$self'.each do |key, val|
      self[key] = decode options.encode['decode'], uri_unescape(val)
    end
  end

  def run_action
    rule = self
    action = rule['action']
    args = rule['args']
    body = action.__call__ args
    body body if defined? body and request.method != 'HEAD'
  end

  def run_before_filters
    rule = self
    @@Filters.each do |filter|
      filter.__call__ rule
    end
  end

  def die_in_request
    stuff = self
    if stuff.is_a?(Schenker::Error) or stuff.is_a?(Schenker::Halt)
      die stuff
    end
    Schenker::Error.raise stuff
  end

  def route_missing
    message = "PATH #{request.path} doesn't match rules"
    Schenker::NotFound.raise message
  end

  def handle_exception
    error = self
    if error.is_a?(Schenker::Halt)
      status error.status if error.status
      body error.message  if error.message
    elsif error.is_a?(Schenker::Error)
      handler = @@Errors[ref error] || @@Errors['Schenker::Error'] || ->{
        status 500
        content_type 'text/plain'
        body 'Internal Server Error'
      }
      handler.__call__ error
    else
      # NOTREACHED
      die
    end
  end

  def dispatch(res)
    req = self
    stash = {}

    local do
      no warnings 'redefine'
      request = (->{ req }).to_glob
      response = (->{ res }).to_glob
      stash = (make_stash stash).to_glob
      session = make_session.to_glob
      error = method(:error_in_request).to_glob
      not_found = method(:not_found_in_request).to_glob

      no strict 'refs'
      __lvar__["$App\\::request"] = method(:request).to_glob
      __lvar__["$App\\::response"] = method(:response).to_glob
      __lvar__["$App\\::stash"] = method(:stash).to_glob
      __lvar__["$App\\::session"] = method(:session).to_glob
      __lvar__["$App\\::error"] = method(:error).to_glob
      __lvar__["$App\\::not_found"] = method(:not_found).to_glob

      use strict
      use warnings
      $@ = nil
      SIG[:__DIE__] = method :die_in_request
    end

    begin
      rule = Schenker::Router.match req
      route_missing unless rule
      parse_nested_query
      decode_args rule['args']
      run_before_filters rule
      run_action rule
    rescue
      handle_exception $@
    end
  end

  def request_handler
    req = self
    res = HTTP::Engine::Response.new
    dispatch req, res
    res
  end

  def init
    @@Initialized and return
    Schenker::Templates.parse_in_file_templates
    Schenker::Engine.init method(:request_handler)
    @@Initialized = 1
  end

  def run(__no_self__)
    init
    Schenker::Engine.run @_
  end

  def exit
    @@Exited = 1
    CORE::exit self
  end

  def run_at_end
    $? == 0        or  return # compile error, die(), exit() with non-zero value
    defined? @@App or  return # run this file as script
    @@Initialized  and return # already called run()
    @@Exited       and return # -h given
    options.run    or  return # disable 'run';
    run
  end

  END {
    run_at_end
  }

  configure do
    set 'environment', ENV['SCHENKER_ENV'] || 'development'
    disable 'sessions'
    enable 'logging'
    enable 'reload'
    set 'root' do file(@@AppFile).dir end
    enable 'static'
    set 'public' do dir(options.root).subdir('public') end
    set 'views' do dir(options.root).subdir('views') end
    enable 'run'
    set 'server', 'ServerSimple'
    set 'host', '0.0.0.0'
    set 'port', 4567
    set 'app_file', @@AppFile
    enable 'dump_errors'
    enable 'clean_trace'
    disable 'raise_errors'
    disable 'lock'
    enable 'methodoverride'
    set 'listen', nil
    set 'nproc', nil
    set 'pidfile', nil
    set 'daemon', nil
    set 'manager', nil
    set 'keeperr', nil
    set 'encode', {
      'encode' => 'utf-8',
      'decode' => 'utf-8'
    }
    set 'session_options', {
      'state' => {
        'class' => 'Cookie',
        'args' => {
          'name' => 'schenker_sid'
        }
      },
      'store' => {
        'class' => 'OnMemory',
        'args' => {},
      }
    }
    tt_options 'ENCODING', 'utf-8'

    # for prove
    if ENV['HARNESS_ACTIVE']
      set 'server', 'Test'
      set 'environment', 'test'
      disable 'run'
    end

    # for mod_perl
    if ENV['MOD_PERL']
      set 'server', 'ModPerl'
      disable 'run'
    end

    Schenker::Options.parse_argv

    configure 'development' do
      Before do
        headers 'X-Schenker', @@VERSION
      end
      error do |__self__|
        warn self
        status 500
        content_type 'text/html'
        body :$self.stack_trace.as_html 'powered_by', 'Schenker' # TODO
      end
      not_found do |__self__|
          status 404
          content_type 'text/html'
          body <<"END_HTML"
  <!DOCTYPE html>
  <html>
  <head>
      <style type="text/css">
      body { text-align:center;font-family:helvetica,arial;font-size:22px;
      color:#888;margin:20px}
      #c {margin:0 auto;width:500px;text-align:left}
      </style>
  </head>
  <body>
      <h2>Schenker doesn't know this lick.</h2>
      <div id="c">
      Try this:
      <pre>@{[lc request->method]} '@{[request->path]}' => sub {\n  "Hello World";\n};</pre>
      </div>
  </body>
  </html>
END_HTML
      end
    end

    configure %w(test production) do
      error do |__self__|
        warn self
        status 500
        content_type 'text/html; charset=iso-8859-1'
        body <<'END_HTML'
<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">
<html><head>
<title>500 Internal Server Error</title>
</head><body>
<h1>Internal Server Error</h1>
<p>The server encountered an internal error or
misconfiguration and was unable to complete
your request.</p>
<p>Please contact the server administrator,
and inform them of the time the error occurred,
and anything you might have done that may have
caused the error.</p>
<p>More information about this error may be available
in the server error log.</p>
</body></html>
END_HTML
      end
      not_found do |__self__|
        status 404
        content_type 'text/html; charset=iso-8859-1'
        body <<"END_HTML"
<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">
<html><head>
<title>404 Not Found</title>
</head><body>
<h1>Not Found</h1>
<p>The requested URL @{[request->path]} was not found on this server.</p>
</body></html>
END_HTML
      end
    end
  end

  no Any::Moose
  self.meta.make_immutable
end
