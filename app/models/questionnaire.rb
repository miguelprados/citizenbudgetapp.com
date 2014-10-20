require 'mail'

class Questionnaire
  include Mongoid::Document
  include Mongoid::Paranoia
  include Mongoid::Timestamps
  include Mongoid::MultiParameterAttributes

  MODES = %w(services taxes)
  ASSESSMENT_PERIODS = %w(month year)

  belongs_to :organization, index: true
  embeds_many :sections
  has_many :responses
  embeds_one :google_api_authorization, autobuild: true
  mount_uploader :logo, ImageUploader
  mount_uploader :title_image, ImageUploader

  # Basic
  field :title, type: String
  field :locale, type: String
  field :starts_at, type: Time
  field :ends_at, type: Time
  field :time_zone, type: String
  field :domain, type: String
  field :email_required, type: Boolean, default: true

  # Mode
  field :mode, type: String
  field :starting_balance, type: Integer
  field :maximum_deviation, type: Integer
  field :default_assessment, type: Integer
  field :assessment_period, type: String, default: 'month'
  field :tax_rate, type: Float
  field :tax_revenue, type: Integer
  field :change_required, type: Boolean

  # Appearance
  field :logo, type: String
  field :title_image, type: String
  field :introduction, type: String
  field :instructions, type: String
  field :read_more, type: String
  field :content_before, type: String
  field :content_after, type: String
  field :description, type: String
  field :attribution, type: String
  field :stylesheet, type: String
  field :javascript, type: String

  # Thank-you email
  field :reply_to, type: String
  field :thank_you_subject, type: String
  field :thank_you_template, type: String

  # Individual response
  field :response_notice, type: String
  field :response_preamble, type: String
  field :response_body, type: String

  # Third-party integration
  field :google_analytics, type: String # tracking code
  field :google_analytics_profile, type: String # table ID
  field :twitter_screen_name, type: String
  field :twitter_text, type: String
  field :twitter_share_text, type: String
  field :facebook_app_id, type: String
  field :open_graph_title, type: String
  field :open_graph_description, type: String
  field :authorization_token, type: String

  # Image uploaders
  field :logo_width, type: Integer
  field :logo_height, type: Integer
  field :title_image_width, type: Integer
  field :title_image_height, type: Integer

  attr_protected :authorization_token, :logo_width, :logo_height,
    :title_image_width, :title_image_height

  index domain: 1

  validates_presence_of :title, :organization_id, :mode
  validates_presence_of :default_assessment, :tax_rate, if: ->(q){q.mode == 'taxes'}
  validates_presence_of :tax_revenue, if: ->(q){q.mode == 'services' && q.tax_rate?}
  validates_inclusion_of :mode, in: MODES, allow_blank: true
  validates_inclusion_of :locale, in: Locale.available_locales, allow_blank: true
  validates_inclusion_of :time_zone, in: ActiveSupport::TimeZone.all.map(&:name), allow_blank: true
  validates_numericality_of :starting_balance, only_integer: true, allow_blank: true
  validates_numericality_of :maximum_deviation, greater_than_or_equal_to: 0, only_integer: true, allow_blank: true
  validates_numericality_of :default_assessment, :tax_revenue, greater_than: 0, only_integer: true, allow_blank: true
  validates_numericality_of :tax_rate, greater_than: 0, less_than: 1, allow_blank: true
  validates_length_of :twitter_text, maximum: 140, allow_blank: true
  validates_length_of :twitter_share_text, maximum: 140, allow_blank: true
  validates_uniqueness_of :domain, allow_blank: true
  validates :reply_to, email: true, allow_blank: true
  validate :ends_at_must_be_greater_than_starts_at
  validate :domain_must_be_active
  validate :domain_must_not_be_blacklisted
  validate :reply_to_must_be_valid
  validate :mode_must_match_options

  before_validation :sanitize_domain
  before_save :add_domain
  before_create :set_authorization_token

  scope :current, where(:starts_at.ne => nil, :ends_at.ne => nil, :starts_at.lte => Time.now, :ends_at.gte => Time.now)
  scope :future, where(:starts_at.ne => nil, :starts_at.gt => Time.now)
  scope :past, where(:ends_at.ne => nil, :ends_at.lt => Time.now)
  scope :active, where(:ends_at.ne => nil, :ends_at.gte => Time.now)

  # @param [String] domain a domain name
  # @return [Enumerable] questionnaires whose domain name matches
  # @note No two active questionnaires should have the same domain.
  def self.by_domain(domain)
    any_in(domain: [domain, sanitize_domain(domain)])
  end

  # @param [String] domain a domain name
  # @return [Questionnaire,nil] a questionnaire whose domain name matches
  # @note No two active questionnaires should have the same domain.
  def self.find_by_domain(domain)
    domain && current.by_domain(domain).first
  end

  # @return [Integer] the number of responses by date in the local time zone
  def count_by_date
    # new Date() always parses the date into the current time zone. getTime()
    # returns the number of milliseconds since epoch. getTimezoneOffset()
    # returns the offset in minutes. In case we can't assume that MongoDB is
    # running in UTC, we add the local time zone offset.
    responses.map_reduce(%Q{
      function () {
        var date = new Date(this.created_at.getTime() + this.created_at.getTimezoneOffset() * 60000 + #{offset} * 1000);
        emit({year: date.getFullYear(), month: date.getMonth() + 1, day: date.getDate()}, 1);
      }
    }, %Q{
      function (key, values) {
        return Array.sum(values);
      }
    }).out(inline: true)
  end

  # @return [Integer] the median number of seconds to complete the questionnaire
  def time_to_complete
    times = responses.map{|response|
      response.created_at - response.initialized_at
    }.select{|time|
      time < 3600 # if longer than an hour, probably left tab open in background
    }.sort

    middle = times.size / 2

    if times.size.zero?
      0
    elsif times.size.odd?
      times[middle]
    else
      (times[middle - 1] + times[middle]) / 2.0
    end
  end

  # @return [Integer] the number of days elapsed
  def days_elapsed
    (today - starts_on).to_i
  end

  # @return [Integer] the number of days left
  def days_left
    (ends_on - today).to_i
  end

  # @return [Time] the consultation's start date in its time zone
  def local_starts_at
    if time_zone?
      starts_at.in_time_zone(time_zone)
    else
      starts_at
    end
  end

  # @return [Time] the consultation's end date in its time zone
  def local_ends_at
    if time_zone?
      ends_at.in_time_zone(time_zone)
    else
      ends_at
    end
  end

  # @return [Date] the consultation's start date in its time zone
  def starts_on
    local_starts_at.to_date
  end

  # @return [Date] the consultation's end date in its time zone
  def ends_on
    local_ends_at.to_date
  end

  # @return [Date] the current date in the consultation's time zone
  def today
    if time_zone?
      Time.now.in_time_zone(time_zone).to_date
    else
      Date.today
    end
  end

  # @return [Integer] the time zone offset in seconds
  # @note If the consultation crosses a clock shift, the offset will be
  #   incorrect for the final days of the consultation.
  def offset
    if starts_at? && time_zone?
      starts_at.in_time_zone(time_zone).utc_offset # respects DST
    else
      0
    end
  end

  # @return [String,nil] the consultation's URL, or nil
  def domain_url
    domain? && "http://#{domain}"
  end

  # @return [Boolean] whether the questionnaire has a maximum deviation
  def maximum_deviation?
    super && maximum_deviation.nonzero?
  end

  # @return [Boolean] whether respondents must submit balanced budgets
  def balance?
    mode == 'services' && tax_rate.blank?
  end

  # @return [Boolean] whether to collect a property value assessment
  def assessment?
    default_assessment? && tax_rate?
  end

  # @return [Boolean] whether the consultation is currently running
  def current?
    starts_at? && ends_at? && starts_at <= Time.now && Time.now <= ends_at
  end

  # @return [Boolean] whether the consultation will start in the future
  def future?
    starts_at? && starts_at > Time.now
  end

  # @return [Boolean] whether the consultation started in the past
  def started?
    starts_at? && starts_at <= Time.now
  end

  # @return [Boolean] whether the consultation will end in the future
  def active?
    ends_at? && ends_at >= Time.now
  end

  # @return [Boolean] whether the consultation ended in the past
  def past?
    ends_at? && ends_at < Time.now
  end

  # @return [Float] the largest surplus possible
  def maximum_amount
    sum = 0
    sections.budgetary.each do |section|
      section.questions.budgetary.each do |question|
        sum += question.maximum_amount
      end
    end
    sum
  end

  # @return [Float] the largest deficit possible
  def minimum_amount
    sum = 0
    sections.budgetary.each do |section|
      section.questions.budgetary.each do |question|
        sum += question.minimum_amount
      end
    end
    sum
  end

  # @return [Array] a list of headers for a spreadsheet
  def headers
    # If the first two letters of a file are "ID", Microsoft Excel will try to
    # open the file in the SYLK file format.
    headers = %w(ip id created_at time_to_complete email name)
    if assessment?
      headers << 'assessment'
    end
    headers
  end

  # @return [Array] rows for a spreadsheet
  def rows
    rows = []

    # Add headers
    row = headers.map do |column|
      Response.human_attribute_name(column)
    end
    sections.each do |section|
      section.questions.each do |question|
        row << question.title
      end
    end
    rows << row

    # Add defaults
    row = headers.map do |column|
      I18n.t(:default)
    end
    sections.each do |section|
      section.questions.each do |question|
        row << question.default_value || I18n.t(:default)
      end
    end
    rows << row

    # Add data
    responses.each do |response|
      row = headers.map do |column|
        if column == 'id'
          response.id.to_s # axlsx may error when trying to convert Moped::BSON::ObjectId
        elsif column != 'assessment' || assessment?
          response.send column
        end
      end
      sections.each do |section|
        section.questions.each do |question|
          answer = response.cast_answer(question)
          if Array === answer
            row << answer.to_sentence
          else
            row << answer
          end
        end
      end
      rows << row
    end

    rows
  end

  def cache_key
    if new_record?
      "#{model_key}/new"
    elsif current?
      "#{model_key}/#{id}-#{updated_at.utc.to_s(:number)}-current"
    else
      "#{model_key}/#{id}-#{updated_at.utc.to_s(:number)}"
    end
  end

  def chart_data # @todo Significant duplication of dashboard.rb
    number_of_responses = responses.count

    all_details = {}
    sections.simulator.map(&:questions).flatten.each do |question|
      details = {}
      if question.budgetary?
        changes = responses.where(:"answers.#{question.id}".ne => question.default_value)
        number_of_changes = changes.count
        number_of_nonchanges = number_of_responses - number_of_changes

        # Start with all the respondents who did not change the value.
        choices = [question.cast_default_value] * number_of_nonchanges

        changes.each do |response|
          choices << response.cast_answer(question)
        end

        details.merge!({
          :choices => choices,
          # Question parameters.
          :minimum_units => question.minimum_units,
          :maximum_units => question.maximum_units,
          :step          => question.step,
          :unit_name     => question.unit_name,
          :default_value => question.default_value,
          :widget        => question.widget,
          # How large were the modifications?
          :mean_choice   => choices.sum / number_of_responses.to_f,
          :n             => number_of_responses,
        })

        if question.widget == 'option'
          details[:counts] = Hash.new(0)
          changes.each do |response|
            details[:counts][response.answer(question)] += 1
          end
          details[:counts][question.default_value] = number_of_nonchanges

          details[:raw_counts] = details[:counts].clone
          details[:counts].each do |option,count|
            details[:counts][option] /= number_of_responses.to_f
          end

          details[:options] = question.options
          details[:labels] = question.labels
        end
      # Multiple choice survey questions.
      elsif question.options?
        changes = responses.where(:"answers.#{question.id}".ne => nil)
        number_of_changes = changes.count

        details[:counts] = {}
        question.options.each do |option|
          details[:counts][option] = 0
        end
        changes.each do |response|
          answer = response.answer(question)
          if question.multiple?
            answer.each do |a|
              details[:counts][a] += 1
            end
          else
            details[:counts][answer] += 1
          end
        end

        details[:raw_counts] = details[:counts].clone
        if number_of_changes.nonzero?
          details[:counts].each do |answer,count|
            details[:counts][answer] /= number_of_changes.to_f
          end
        end
      end

      all_details[question.id.to_s] = details
    end

    all_details
  end

private

  # Removes the protocol, "www" and trailing slash, if present.
  # @param [String] domain a domain name
  # @return [String] the domain without the protocol or trailing slash
  def self.sanitize_domain(domain)
    domain.sub(%r{\A(https?://)?(www\.)?}, '').sub(%r{/\z}, '')
  end

  def sanitize_domain
    if domain?
      self.domain = self.class.sanitize_domain(domain)
    end
  end

  def ends_at_must_be_greater_than_starts_at
    if starts_at? && ends_at? && starts_at > ends_at
      errors.add(:ends_at, I18n.t('errors.messages.ends_at_must_be_greater_than_starts_at'))
    end
  end

  def domain_must_be_active
    if domain? && !domain[/\A[a-z]+\.(citizenbudget|budgetcitoyen)\.com\z/] # @todo Remove hardcode.
      begin
        Socket.gethostbyname(domain)
      rescue SocketError
        errors.add(:domain, I18n.t('errors.messages.domain_must_be_active'))
      end
    end
  end

  def domain_must_not_be_blacklisted
    if domain?
      Locale.available_locales.each do |locale|
        if [I18n.t('app.host', locale: locale), I18n.t('app.domain', locale: locale)].include?(domain)
          errors.add(:domain, I18n.t('errors.messages.domain_must_not_be_blacklisted'))
        end
      end
    end
  end

  def reply_to_must_be_valid
    if reply_to?
      begin
        address = Mail::Address.new(Mail::Address.new(reply_to).address)
        unless address.domain && address.domain.split('.').size > 1
          errors.add(:reply_to, I18n.t('errors.messages.reply_to_must_be_valid'))
        end
      rescue Mail::Field::ParseError
        errors.add(:reply_to, I18n.t('errors.messages.reply_to_must_be_valid'))
      end
    end
  end

  def mode_must_match_options
    if maximum_deviation?
      if mode == 'taxes'
        errors.add(:mode, I18n.t('errors.messages.maximum_deviation_must_not_be_set_in_taxes_mode'))
      elsif tax_rate?
        errors.add(:mode, I18n.t('errors.messages.maximum_deviation_and_tax_rate_must_not_both_be_set'))
      end
    end
  end

  def set_authorization_token
    loop do
      self.authorization_token = SecureRandom.base64(15).tr('+/=lIO0', 'pqrsxyz')
      break unless self.class.where(authorization_token: authorization_token).first
    end
  end

  # Adds the questionnaire's domain to the app's custom domains list on Heroku.
  # @todo Will not add a "www" subdomain to domains ending in "co.uk"
  def add_domain
    if HerokuClient.configured? && domain_changed?
      domains = HerokuClient.list_domains

      if domain_was.present?
        queue = [domain_was]
        if domain_was.split('.').size == 2
          queue << "www.#{domain_was}"
        end
        queue.each do |d|
          if domains.include?(d)
            HerokuClient.remove_domain(d)
          end
        end
      end

      if domain.present?
        queue = [domain]
        if domain.split('.').size == 2
          queue << "www.#{domain}"
        end
        queue.each do |d|
          unless domains.include?(d)
            HerokuClient.add_domain(d)
          end
        end
      end
    end
  end
end
