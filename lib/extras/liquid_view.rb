# LiquidView is a action view extension class. You can register it with rails
# and use liquid as an template system for .liquid files
#
# Example
# 
#   ActionView::Base::register_template_handler :liquid, LiquidView
class LiquidView
  PROTECTED_ASSIGNS = %w( template_root response _session template_class action_name request_origin session template
                          _response url _request _cookies variables_added _flash params _headers request cookies
                          ignore_missing_templates flash _params logger before_filter_chain_aborted headers )
  PROTECTED_INSTANCE_VARIABLES = %w( @_request @controller @_first_render @_memoized__pick_template @view_paths 
                                     @helpers @assigns_added @template @_render_stack @template_format @assigns )
  
  def self.call(template)
    "LiquidView.new(self).render(#{template.source.inspect}, local_assigns)"
  end

  def initialize(view)
    @view = view
  end

  def render(template, local_assigns = { })
    @view.controller.headers["Content-Type"] ||= 'text/html; charset=utf-8'

    assigns = @view.assigns

    if @view.content_for?(:layout)
      assigns["content_for_layout"] = @view.content_for(:layout)
    end
    assigns.merge!(local_assigns.stringify_keys)

    if @view.controller.user

      if template.instance_of?(ActionView::InlineTemplate)
        liquid = ::Rails.cache.fetch(Digest::SHA512.hexdigest(template.source)) do
          liquid = Liquid::Template.parse(source)
          Marshal.dump(liquid)
        end

        Marshal.load(liquid).render(assigns,
          :filters => [],
          :registers => {
            :action_view => @view,
            :controller => @view.controller
          })
      else

        liquid = Liquid::Template.parse(source)
        liquid.render(assigns,
          :filters => [],
          :registers => {
            :action_view => @view,
            :controller => @view.controller
          })
      end

    else  

      locale = @view.controller.locale
      location = @view.controller.location ? @view.controller.location.current_country_short : ''

      key = [:site, @view.controller.site.versioned_cache_key, locale, location, template.path, @view.controller.request.url] if @view.controller.site

      Rails.cache.fetch(key, :expires_in => 1.hour) do
        # Init the template filesystem for snippets and includes
        Liquid::Template.file_system = Liquid::LocalFileSystem.new('site')
        
        template = Modyo::Instrumentation::Agent.inject(template)

        if template.instance_of?(ActionView::InlineTemplate)
          liquid = ::Rails.cache.fetch(Digest::SHA512.hexdigest(template.source)) do
            liquid = Liquid::Template.parse(source)
            Marshal.dump(liquid)
          end

          Marshal.load(liquid).render(assigns,
            :filters => [], 
            :registers => {
              :action_view => @view,
              :controller => @view.controller
            })
        else

          liquid = Liquid::Template.parse(source)
          liquid.render(assigns,
            :filters => [], 
            :registers => {
              :action_view => @view,
              :controller => @view.controller
            })
        end
      end

    end
   
  end

  def compilable?
    false
  end

end