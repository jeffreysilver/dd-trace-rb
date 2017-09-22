require 'ddtrace/contrib/rails/utils'

module Datadog
  module Contrib
    module Rails
      # Code used to create and handle 'rails.render_template' and 'rails.render_partial' spans.
      module ActionView
        def self.instrument
          # patch Rails core components
          Datadog::RailsRendererPatcher.patch_renderer()

          # subscribe when the template rendering starts
          ::ActiveSupport::Notifications.subscribe('!datadog.start_render_template.action_view') do |*args|
            start_render_template(*args)
          end

          # subscribe when the template rendering has been processed
          ::ActiveSupport::Notifications.subscribe('!datadog.finish_render_template.action_view') do |*args|
            finish_render_template(*args)
          end

          # subscribe when the partial rendering starts
          ::ActiveSupport::Notifications.subscribe('!datadog.start_render_partial.action_view') do |*args|
            start_render_partial(*args)
          end

          # subscribe when the partial rendering has been processed
          ::ActiveSupport::Notifications.subscribe('!datadog.finish_render_partial.action_view') do |*args|
            finish_render_partial(*args)
          end
        end

        def self.start_render_template(_name, _start, _finish, _id, payload)
          # retrieve the tracing context
          tracing_context = payload.fetch(:tracing_context)

          # create a new Span and add it to the tracing context
          tracer = ::Rails.configuration.datadog_trace.fetch(:tracer)
          span = tracer.trace('rails.render_template', span_type: Datadog::Ext::HTTP::TEMPLATE)
          tracing_context[:dd_rails_template_span] = span
        rescue StandardError => e
          Datadog::Tracer.log.debug(e.message)
        end

        def self.finish_render_template(_name, _start, _finish, _id, payload)
          # retrieve the tracing context and the latest active span
          tracing_context = payload.fetch(:tracing_context)
          span = tracing_context[:dd_rails_template_span]
          return if !span || span.finished?

          # finish the tracing and update the execution time
          begin
            template_name = tracing_context[:template_name]
            layout = tracing_context[:layout]
            exception = tracing_context[:exception]

            span.set_tag('rails.template_name', template_name) if template_name
            span.set_tag('rails.layout', layout) if layout
            span.set_error(exception) if exception
          ensure
            span.finish()
          end
        rescue StandardError => e
          Datadog::Tracer.log.debug(e.message)
        end

        def self.start_render_partial(_name, _start, _finish, _id, payload)
          # retrieve the tracing context
          tracing_context = payload.fetch(:tracing_context)

          tracer = ::Rails.configuration.datadog_trace.fetch(:tracer)
          span = tracer.trace('rails.render_partial', span_type: Datadog::Ext::HTTP::TEMPLATE)
          tracing_context[:dd_rails_partial_span] = span
        rescue StandardError => e
          Datadog::Tracer.log.debug(e.message)
        end

        def self.finish_render_partial(_name, start, finish, _id, payload)
          # retrieve the tracing context and the latest active span
          tracing_context = payload.fetch(:tracing_context)
          span = tracing_context[:dd_rails_partial_span]
          return if !span || span.finished?

          # finish the tracing and update the execution time
          begin
            template_name = tracing_context[:template_name]
            exception = tracing_context[:exception]

            span.set_tag('rails.template_name', template_name) if template_name
            span.set_error(exception) if exception
          ensure
            span.finish()
          end
        rescue StandardError => e
          Datadog::Tracer.log.debug(e.message)
        end
      end
    end
  end
end
