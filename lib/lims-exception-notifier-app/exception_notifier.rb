require 'yaml'
require 'net/smtp'
require 'cgi'
require 'mustache'

module Lims
  module ExceptionNotifierApp
    # When an unchecked exception raised in the host application, this class
    # should handle it. It sends an e-mail as a notification to a configurable
    # recepient.
    # The e-mail message based on a template, so it is configurable, too.
    # To not 'silently eat' our caught and unchecked exception, this class raises
    # it again, after the class sent the e-mail.
    class ExceptionNotifier

      # @param [Symbol/String] env_mode the environment name to use. E.g: :development
      def initialize(env_mode)
        @email_options = YAML.load_file(load_config_file('config','email.yml'))[env_mode.to_s]
        @email_header = @email_options['header']
      end

      # @param [Lambda] block to check if there is an exception raised
      def notify(&block)
        begin
          block.call
        rescue Exception => exception
          send_notification_email(exception)

          # reraise the original exception
          raise exception
        end
      end

      # @param [Exception] ex the raised exception to handle
      # @param [Hash] env represents the environmental variable(s) of the HTTP server
      # This variable is nil, if the exception is not raised inside a rack application.
      def send_notification_email(ex, env = nil)
        exception_data = process_exception(ex)
        environment_data = process_environment(env) if env
        send_email(exception_data, environment_data)
      end

      private

      # This method is processing the environmental variables and returning a
      # hash containing all these variables and some other values processed
      # from them.
      # @param [Hash] env represents the environmental variable(s) of the HTTP server
      def process_environment(env)
        request_data = { 
          :url        => env['REQUEST_URI'],
          :ip_address => env['HTTP_X_FORWARDED_FOR'] ? env['HTTP_X_FORWARDED_FOR'] : env['REMOTE_ADDR']
        }
        request_data[:user] = env['HTTP_USER_EMAIL'] if env['HTTP_USER_EMAIL']

        env['rack.input'].rewind
        parameters = ''
        env['rack.input'].each { |line| parameters += line }
        request_data[:parameters] = parameters if parameters

        { :environment_data => env.map { |l| " * #{l}" }.join("\n"),
          :request_data     => request_data
        }
      end

      # Gets the file context where the exception was raised
      def get_context(file, line_number)
        # TODO add file context
      end

      # Assemble the caught exception's class, message and its back trace to a hash
      # @param [Exception] exception the caught exception to handle
      def process_exception(exception)
        exception_data = {
          :exception =>
            { :class      => exception.class,
              :message    => exception.message,
              :backtrace  => exception.backtrace.map { |l| "\t#{l}" }.join("\n")
            }
          }
      end

      # Processes the e-mail template and sends it as an e-mail
      # @param [Hash] exception_data data related to the caught exception
      # @param [Hash] environment_data data related to the server environment
      def send_email(exception_data, environment_data)
        email_template = File.open(load_config_file(['email_templates'], @email_options['template'])) { |f| f.read }
        message = CGI::unescapeHTML(Mustache.render(email_template, 
          @email_header.merge!(exception_data)))
        message.merge!(environment_data) if environment_data

        Net::SMTP.start(@email_options["server"]) do |smtp|
          smtp.send_message(message, @email_header["from"], @email_header["to"])
        end
      end

      # Loads a config file for a relative path
      # @param [Array] folders the list of folders, where the file exists
      # @param [String] filename the name of the file to load
      def load_config_file(folders, filename)
        File.expand_path(File.join(File.dirname(__FILE__), '../..', folders, filename))
      end
    end
  end
end
