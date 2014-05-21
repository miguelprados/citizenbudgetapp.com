$ ->
  # Sharing.
  $(document).on 'mouseup', '#url-field', ->
    $(this).select()

  $('.clippy').clippy
    clippy_path: '/assets/clippy.swf'
    text: $('#url-field').val()
    flashvars:
      args: 'clippy'

  window.clippyCopiedCallback = (args) ->
    $('#' + args).attr('data-original-title', t('copied_hint')).tooltip('show').attr('data-original-title', t('copy_hint'))

  # If the page is cached, initialized_at will not be set appropriately.
  now = new Date()
  $('#response_initialized_at').val("#{now.getUTCFullYear()}-#{now.getUTCMonth() + 1}-#{now.getUTCDate()} #{now.getUTCHours()}:#{now.getUTCMinutes()}:#{now.getUTCSeconds()} UTC")

  # Open non-Bootstrap links in new windows.
  $('.description a:not([class]),.modal.embed a:not([class])').attr('target', '_blank')

  # Initialize Bootstrap plugins.
  $('.dropdown-toggle').dropdown()

  $('.popover-toggle').popover(trigger: 'click').click (event) -> event.preventDefault()
  $('[rel="tooltip"]').tooltip()

  # Bootstrap hacks.
  $('.modal').bind 'shown', ->
    $(this).removeClass('invisible')
  $('.modal').bind 'hidden', ->
    $(this).addClass('invisible')

  # Navigation
  (->
    # If we want a fixed top bar.
    if $('#whitespace').length
      $window     = $(window)
      $nav        = $('nav')
      $message    = $('#message')
      $whitespace = $('#whitespace')

      if $nav.length
        target = 'nav'
        offset = $nav.offset().top
        height = $nav.outerHeight() + $message.outerHeight()
        $receiver = $nav
      else
        target = '#message'
        offset = $message.offset().top
        height = $message.outerHeight()
        $receiver = $message

      # Set active menu item.
      $('body').scrollspy
        target: target
        offset: height

      # Smooth scrolling.
      $receiver.localScroll
        axis: 'y'
        duration: 500
        easing: 'easeInOutExpo'
        offset: -height
        hash: true

      # Fixed menu.
      processScroll = ->
        boolean = $window.scrollTop() >= offset
        $nav.toggleClass('nav-fixed', boolean)
        $message.toggleClass('message-fixed', boolean)
        $whitespace.css(height: height).toggle(boolean)

      $window.on('scroll', processScroll)
      processScroll()
  )()

  # Smooth scroll "submit your choices" link.
  $('.message').on 'click', 'a[href="#identification"]', (event) ->
    $.scrollTo '#identification',
      axis: 'y'
      duration: 500
      easing: 'easeInOutExpo'
      offset: -50
    event.preventDefault()

  if $('#response_count').length
    $.ajax(url: '/responses/count.json' + (location.href.match(/\?token=.+/) || '')).done (data) ->
      $('#response_count').html(data)
