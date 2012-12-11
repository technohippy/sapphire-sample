class Schenker::Router
  require 'any/moose'
  use base 'Exporter'
  require 'carp', %w(croak)
  require 'h_t_t_px/dispatcher'

  @@EXPORT = %w(get head post put Delete)

  def route(__no_self__, method, path, *args)
    croak 'method required' unless method
    croak 'path required' unless path
    action = args.pop
    croak 'action must be coderef' unless action.is_a? CODE
    options = args.to_hash
    function = nil

    if host = options['host'] || options['host_name']
      function = ->{
        if host.is_a? Regexp
          Schenker.request.uri.host =~ host
        else
          Schenker.request.uri.host.eq host
        end
      }
    end

    if agent = options['agent'] || options['user_agent']
      orig_func = function
      function = ->{
        if orig_func
          :'$orig_func->() or return 0;' # TODO
        end
        if agent.is_a? Regexp
          Schenker.request.user_agent =~ agent
        else
          Schenker.request.user_agent.eq agent
        end
      }
    end

    %x'$path =~ s|^/||;' # TODO
    conditions = ['method', method].to_hash
    if defined function
      conditions['function'] = function
    end
    connect path, {
      'controller' => self.class,
      'action' => action,
      #'conditions' => conditions.to_ref # TODO
      'conditions' => {
        'method' => method,
        'function' => function
      }
    }
  end

  def head(__no_self__)
    route 'HEAD', @_ 
  end

  def get(__no_self__)
    route %w(GET HEAD).to_arrayref, @_ 
  end

  def post(__no_self__)
    route 'POST', @_ 
  end

  def Delete(__no_self__)
    route 'DELETE', @_ 
  end

  def put(__no_self__)
    route 'PUT', @_ 
  end

  no Any::Moose
  self.meta.make_immutable
end
