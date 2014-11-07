# coding: utf-8
require 'csv'

ActiveAdmin.register_page 'Dashboard' do
  menu priority: 1, label: proc{ I18n.t('active_admin.dashboard') }

  # Instance variables set here will not be accessible from the template.
  content title: proc{ I18n.t('active_admin.dashboard') } do
    render 'index'
  end

  # @todo Changing language from here will lose the "id" query string parameter,
  #   causing a 404.
  page_action 'summary', title: '@todo' do
    @questionnaire = current_admin_user.questionnaires.find(params[:id])
    authorize! :read, @questionnaire

    # Header
    @starts_on = @questionnaire.starts_on
    @ends_on   = [@questionnaire.today, @questionnaire.ends_on].min

    # Timeline and web traffic
    @charts, @statistics = charts @questionnaire

    # Collections
    @responses = @questionnaire.responses
    @questions = @questionnaire.sections.map(&:questions).flatten
    @number_of_responses = @responses.count

    @details = {}
    @questions.each do |question|
      details = {}
      if question.budgetary?
        changes = @responses.where(:"answers.#{question.id}".ne => question.default_value)
        number_of_changes = changes.count
        number_of_nonchanges = @number_of_responses - number_of_changes

        # Start with all the respondents who did not change the value.
        choices = [question.cast_default_value] * number_of_nonchanges
        impacts = []

        changes.each do |response|
          choices << response.cast_answer(question)
          impacts << response.impact(question)
        end

        details.merge!({
          # How many respondents modified this question?
          :percentage_of_population => number_of_changes / @number_of_responses.to_f,
          # How large were the modifications?
          :mean_choice => choices.sum / @number_of_responses.to_f,
          :mean_impact => impacts.sum / @number_of_responses.to_f,
        })

        increases = choices.select{|v| v > question.cast_default_value}
        if increases.empty?
          details[:proportion_who_increase] = 0.0
          details[:mean_increase] = 0.0
        else
          details[:proportion_who_increase] = increases.size / number_of_changes.to_f
          details[:mean_increase] = increases.sum / increases.size.to_f
        end

        decreases = choices.select{|v| v < question.cast_default_value}
        if decreases.empty?
          details[:proportion_who_decrease] = 0.0
          details[:mean_decrease] = 0.0
        else
          details[:proportion_who_decrease] = decreases.size / number_of_changes.to_f
          details[:mean_decrease] = decreases.sum / decreases.size.to_f
        end

        if question.widget == 'option'
          details[:counts] = Hash.new(0)
          changes.each do |response|
            details[:counts][response.answer(question)] += 1
          end
          details[:counts][question.default_value] = number_of_nonchanges

          details[:counts].each do |option,count|
            details[:counts][option] /= @number_of_responses.to_f
          end
        end
      # Multiple choice survey questions.
      elsif question.options?
        changes = @responses.where(:"answers.#{question.id}".ne => nil)
        number_of_changes = changes.count

        # How many respondents modified this question?
        details[:percentage_of_population] = number_of_changes / @number_of_responses.to_f

        details[:counts] = Hash.new(0)
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

        if number_of_changes.nonzero?
          details[:counts].each do |answer,count|
            details[:counts][answer] /= number_of_changes.to_f
          end
        end
      end

      @details[question.id.to_s] = details
    end

    # @see https://github.com/gregbell/active_admin/issues/1362
    render 'summary', layout: 'active_admin'
  end

  # Excel doesn't properly decode UTF-8 CSV and TSV files. A UTF-8 byte order
  # mark (BOM) can be added to fix the problem, but Excel for Mac will still
  # have issues. XLS and XLSX are therefore offered.
  page_action 'raw' do
    @questionnaire = current_admin_user.questionnaires.find(params[:id])
    authorize! :read, @questionnaire

    filename = "data-#{Time.now.strftime('%Y-%m-%d')}.#{params[:format]}"

    # http://www.rfc-editor.org/rfc/rfc4180.txt
    case params[:format]
    when 'csv'
      @col_sep = ','
      headers['Content-Type'] = 'text/csv; charset=utf-8; header=present'
      headers['Content-Disposition'] = %(attachment; filename="#{filename}")
      render layout: false

    when 'tsv'
      @col_sep = "\t"
      headers['Content-Type'] = 'text/tab-delimited-values; charset=utf-8; header=present'
      headers['Content-Disposition'] = %(attachment; filename="#{filename}")
      render layout: false

    when 'xls'
      io = StringIO.new

      book = Spreadsheet::Workbook.new
      sheet = book.create_worksheet
      @questionnaire.rows.each_with_index do |row,i|
        sheet.row(i).concat(row)
      end
      book.write(io)

      send_data io.string, filename: filename, type: 'application/vnd.ms-excel'

    when 'xlsx'
      xlsx = Axlsx::Package.new do |package|
        package.workbook.add_worksheet do |sheet|
          @questionnaire.rows.each do |row|
            begin
              sheet.add_row(row)
            rescue ArgumentError => e # non-UTF8 characters from spammers
              logger.error "#{e.inspect}: #{row.inspect}"
            end
          end
        end
      end

      send_data xlsx.to_stream.string, filename: filename, type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'

    else
      redirect_to admin_root_path, notice: t(:unknown_format)
    end
  end

  controller do
    def index
      @questionnaires = current_admin_user.questionnaires
    end

  protected

    # @param [Questionnaire] q a questionnaire
    # @return [Array] the charts and statistics as a two-value array
    #
    # @see http://analytics-api-samples.googlecode.com/svn/trunk/src/reporting/javascript/ez-ga-dash/docs/user-documentation.html
    # @see http://analytics-api-samples.googlecode.com/svn/trunk/src/reporting/javascript/ez-ga-dash/demos/set-demo.html
    def charts(q)
      charts = {}
      statistics = {}

      # Make all graphs for a consultation have the same x-axis.
      starts_on = q.starts_on
      ends_on = [q.today, q.ends_on].min

      begin
        # Responses per day.
        data = []
        hash = q.count_by_date.each_with_object({}) do |row,memo|
          memo[Date.new(row['_id']['year'], row['_id']['month'], row['_id']['day'])] = row['value']
        end
        # Add zeroes so that the chart doesn't interpolate between values.
        starts_on.upto(ends_on).each do |date|
          data << %([#{date_to_js(date)}, #{hash[date] || 0}])
        end

        charts[:responses] = data.join(',')
      rescue Moped::Errors::OperationFailure
        # Do nothing. JS engine is off.
      end

      if q.google_analytics_profile? && q.google_api_authorization.authorized?
        begin
          parameters = {
            'ids'        => q.google_analytics_profile,
            'start-date' => starts_on,
            'end-date'   => ends_on,
          }

          # Statistics
          data = q.google_api_authorization.reports(parameters.merge({
            'metrics'    => 'ga:users,ga:sessions,ga:pageviews',
          }))

          statistics.merge!({
            name:      Questionnaire.sanitize_domain(data.profileInfo['profileName']),
            property:  data.profileInfo['webPropertyId'],
            visitors:  data.totalsForAllResults['ga:users'],
            visits:    data.totalsForAllResults['ga:sessions'],
            pageviews: data.totalsForAllResults['ga:pageviews'],
          })

          # Traffic per day.
          data = q.google_api_authorization.reports(parameters.merge({
            'dimensions' => 'ga:date',
            'metrics'    => 'ga:users,ga:sessions,ga:pageviews',
            'sort'       => 'ga:date',
          }))
          charts[:visits] = data.rows.map{|row|
            %([#{date_to_js(Date.parse(row[0]))}, #{row[1]}, #{row[2]}, #{row[3]}])
          }.join(',')

          # Traffic sources.
          data = q.google_api_authorization.reports(parameters.merge({
            'dimensions' => 'ga:source',
            'metrics'    => 'ga:users',
            'sort'       => '-ga:users',
          }))
          charts[:sources] = data.rows.map{|row|
            %(["#{row[0]}", #{row[1]}])
          }.join(',')
        rescue GoogleApiAuthorization::AccessRevokedError, GoogleApiAuthorization::APIError, SocketError
          # Omit the chart if there's an error.
        end
      end

      [charts, statistics]
    end

    # Google Charts needs a Date object, so we can't use #to_json.
    #
    # @param [Date,Time,DateTime] date a date
    def date_to_js(date)
      # JavaScript months start counting from zero.
      "new Date(#{date.year}, #{date.month - 1}, #{date.day})"
    end
  end
end
