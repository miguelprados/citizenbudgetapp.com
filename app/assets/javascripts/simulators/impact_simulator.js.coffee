# Respondents can submit any budget. The simulator communicates the impact of
# their budget choices on their tax rate.
class window.ImpactSimulator extends window.Simulator
  # @note If this simulator were to collect the respondent's assessment and if
  #   the reminder message were to mention personal tax impact, we would only
  #   need to update the reminder message when the assessment changes.
  #
  # @example
  #   @setReminder(@net_balance())
  constructor: (@options = {}) ->
    super

    # The texts of the reminder messages.
    @reminders =
      en_US:
        surplus: 'Your choices have decreased the amount of property tax revenue required to balance by {{number}} or {{percentage}}.'
        balanced: 'Your budget is balanced.'
        deficit: 'Your choices have increased the amount of property tax revenue required to balance by {{number}} or {{percentage}}.'
      fr_CA:
        surplus: 'Vos choix ont diminué le total des impôts fonciers requis pour équilibrer le budget de {{number}} ou {{percentage}}.'
        balanced: "Vous avez atteint l'équilibre."
        deficit: 'Vos choix ont augmenté le total des impôts fonciers requis pour équilibrer le budget de {{number}} ou {{percentage}}.'
      uk:
        surplus: 'Ваш вибір зменшив рівень доходу з податку на майно потрібний для балансу на {{number}}, або {{percentage}}.'
        balanced: 'Ваш бюджет збалансовано.'
        deficit: 'Ваш вибір збільшив рівень доходу з податку на майно потрібний для балансу на {{number}}, або {{percentage}}.'

    $('#assessment input').bind 'keydown keypress keyup', (event) ->
      if event.keyCode == 13
        event.preventDefault()
        $(this).blur()

  # Display the default message in the navigation only.
  messageSelector: ->
    '#message'

  setMessage: (net_balance) ->
    super
    @setReminder(net_balance)

  setReminder: (net_balance) ->
    options =
      number: SimulatorHelper.number_to_currency(Math.abs(net_balance), strip_insignificant_zeros: true)
      percentage: SimulatorHelper.number_to_percentage(Math.abs(net_balance) / @options.tax_revenue * 100, strip_insignificant_zeros: true)

    reminder = if net_balance == 0
      if @isChanged()
        t('balanced', {}, @reminders)
      else
        @instructions
    else
      if net_balance < 0
        t('deficit', options, @reminders)
      else
        t('surplus', options, @reminders)

    $('#reminder').html(reminder).toggleClass('hide', not @isChanged())
