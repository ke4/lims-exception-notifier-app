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

      ConfigurationFileMissingError = Class.new(StandardError)

      def initialize
        begin
          @email_options = YAML.load_file(File.join('config','exception-email.yml'))
        rescue Errno::ENOENT => e
          raise ConfigurationFileMissingError, "Configuration file is missing for " +
            "Exception Notifier Application. " +
            "You need a configuration file (exception-email.yml) " +
            "under config folder to use this application."
        end
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
          :request_data     => request_data,
          :server_name      => env["SERVER_NAME"].split('.').first
        }
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
        email_template = File.open(File.expand_path(
          File.join(File.dirname(__FILE__), '../..', ['email_templates'],
            @email_options['template']))) {|f| f.read }

        email_data = @email_header.merge!(exception_data)
        email_data.merge!(environment_data) if environment_data
        email_data.merge!(:application_name => @email_options['application_name']) if @email_options['application_name']

        message = CGI::unescapeHTML(Mustache.render(email_template, email_data))

        Net::SMTP.start(@email_options["server"]) do |smtp|
          smtp.send_message(message, @email_header["from"], @email_header["to"])
        end
      end
    end
  end
end
