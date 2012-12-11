class Schenker::NotFound < Exporter
  require 'any/moose'
  require 'carp', %w(croak)
  require 'm_i_m_e/types'

  @@EXPORT = %w(media_type mime)
  @@MIMETypes = nil

  def mime_type
    @@MIMETypes ||= MIME::Types.new
  end

  def mime(__no_self__, ext, type, encoding, system)
    croak 'usage: mime $ext => $type' if !defined ext or !defined type
    extensions = ext
    extensions = [ext] unless ext.is_a? Array
    type_args = [
      'type', type,
      'extensions', extensions,
    ]
    if defined encoding
      type_args.push 'encoding'
      type_args.push encoding
    end
    if defined system
      type_args.push 'system'
      type_args.push system
    end
    mime_types.addType MIME::Type.new type_args
  end

  no Any::Moose
  self.meta.make_immutable
end
