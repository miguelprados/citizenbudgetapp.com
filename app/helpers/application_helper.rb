module ApplicationHelper
  def bootstrap_form_for(record_or_name_or_array, *args, &proc)
    options = args.extract_options!
    options[:builder] ||= FormtasticBootstrap::FormBuilder
    semantic_form_for record_or_name_or_array, options, &proc
  end

  # Facebook uses underscores in locale identifiers (as do Unix systems).
  def system_locale
    if locale.to_s == 'en'
      'en_US'
    else
      locale.to_s.sub('-', '_')
    end
  end

  def iso639_locale
    locale.to_s.split('-', 2).first
  end

  # <head> tags

  def title
    if @questionnaire
      "#{@questionnaire.organization.name} - #{@questionnaire.title}"
    else
      t 'app.product_name'
    end
  end

  def meta_description
    @questionnaire && @questionnaire.description
  end

  def author
    @questionnaire && @questionnaire.organization.name || t('app.author_name')
  end

  # Open Graph tags

  def og_title
    @questionnaire && @questionnaire.open_graph_title || title
  end

  def og_description
    @questionnaire && @questionnaire.open_graph_description || meta_description
  end

  def og_site_name
    @questionnaire && @questionnaire.title || t('app.product_name')
  end

  def og_url
    @questionnaire && @questionnaire.domain_url || t('app.product_url')
  end

  def og_image
    if @questionnaire && @questionnaire.logo?
      if Rails.env.production?
        'http:' + @questionnaire.logo_url
      else
        root_url.chomp('/') + @questionnaire.logo_url
      end
    end
  end

  # Third-party integration

  def facebook_app_id
    @questionnaire && @questionnaire.facebook_app_id
  end

  def google_analytics_tracking_code
    @questionnaire && @questionnaire.google_analytics || t('.google_analytics')
  end

  # Used in both public and private controllers.

  def token_url(questionnaire)
    root_url(token: questionnaire.authorization_token, domain: questionnaire.domain? && questionnaire.domain || t('app.host'), subdomain: false)
  end

  MAX_DIMENSION = 560 # As for Bootstrap's .modal

  # @param [String] string a Markdown string that may contain HTML
  # @return [String] the HTML output
  def markdown(string)
    RDiscount.new(string).to_html.html_safe
  end

  # @see http://speakerdeck.com/assets/embed.js
  def speakerdeck_or_markdown(html)
    if html['speakerdeck.com/assets/embed.js']
      id = html[/data-id="([0-9a-f]+)"/, 1]
      ratio = html[/data-ratio="([0-9.]+)"/, 1].to_f

      properties = {}
      if ratio >= 1
        properties['width']  = MAX_DIMENSION
        properties['height'] = ((properties['width'] - 2) / ratio + 64).round
      else
        properties['height'] = MAX_DIMENSION
        properties['width']  = ((properties['height'] - 64) * ratio + 2).round
        properties['margin-left'] = ((MAX_DIMENSION - properties['width']) / 2.0).round
      end

      content_tag(:div,
        content_tag(:div, nil,
          'class' => 'speakerdeck-embed', 'data-id' => id, 'data-ratio' => ratio),
        'style' => properties.map{|k,v| "#{k}:#{v}px"}.join(';'))
    else
      content_tag(:div, markdown(html), class: 'extra clearfix')
    end
  end
end
