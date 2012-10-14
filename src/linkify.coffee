﻿Linkify =
  init: ->
    # Add Linkification to callbacks, which will call linkification on every post parsed by Appchan X.
    Main.callbacks.push @node

  # I didn't write most of this RegEx.
  regString: [
    '('
    # leading scheme:// or "www."
    '\\b('
    '[a-z][-a-z0-9+.]+://'
    '|'
    'www\\.'
    '|'
    # Various link handlers:
    'magnet:'
    '|'
    'mailto:'
    '|'
    'news:'
    ')'
    # everything until non-URL character
    '[^\\s\'"<>()]+'
    '|'
    # emails. We don't need everything until a non-URL character because emails follow a consistent syntax.
    '\\b[a-z0-9._%+-]+@[a-z0-9.-]+\\.[a-z]{2,4}\\b'
    ')'
  ].join("")

  embedRegExp: /.*(?:youtu.be\/|v\/|u\/\w\/|embed\/|watch\?v=|youtube.*\&v=)([^#\&\?]*).*/

  node: (post) ->
    # Built based on:
    # - http://en.wikipedia.org/wiki/URI_scheme
    # - http://www.regular-expressions.info/regexbuddy/email.html

    nodes = []

    comment = post.blockquote or $ 'blockquote', post.el
    subject = $ '.subject', post.el

    # We collect all the text children before editting them so that further children don't
    # get offset and therefore don't get parsed.
    for child in comment.childNodes
      if child.nodeType == Node.TEXT_NODE
        nodes.push child
      # Quotes can contain links, too.
      else if child.className == "quote"
        for node in child.childNodes
          if node.nodeType == Node.TEXT_NODE
            nodes.push node

    # We only try to touch the subject if it exists.
    if subject?
      for child in subject.childNodes
        if child.nodeType == Node.TEXT_NODE
          nodes.push child

    # After we generate our list of nodes to parse we can edit it without worrying about nodes getting orphaned.
    for node in nodes
      Linkify.text node

  text: (child, link) ->
    # We need text to parse.
    txt = child.textContent

    # position tracker.
    p = 0

    urlRegExp = new RegExp Linkify.regString, 'i'
    if m = urlRegExp.exec txt

      # Get the link without trailing dots as to not create an invalid link.
      l = m[0].replace /\.*$/, ''

      # Record the URL length so we can remove the URL from the string when we insert the link.
      lLen = l.length

      # Put in text up to the link so we can insert the link after it.
      node = $.tn(txt.substring(p, m.index))

      # Check if we're merging a link with the next text node or creating a new link.
      if link
        $.replace link, node
      else
        $.replace child, node

      # Create the link
      a = $.el 'a'
        textContent: l
        className: 'linkify'
        rel:       'nofollow noreferrer'
        target:    'blank'
        # I haven't found a situation where not having a slash in the conditional breaks anything.
        href:      if l.indexOf(":") < 0 then (if l.indexOf("@") > 0 then "mailto:" + l else "http://" + l) else l

      Linkify.concat(a)

      # We can finally insert the link.
      $.after node, a

      # We check to see if we're also allowing embedding and if we can.
      if Conf['Youtube Embed'] and match = a.href.match Linkify.embedRegExp
        # We create a new element
        embed = $.el 'a'
          name:         match[1]
          className:    'embedlink'
          href:         'javascript:;'
          textContent:  '(embed)'

        # and allow the user to click it to embed the video.
        $.on embed, 'click', Linkify.embed

        # We insert the embed link after the pre-existing link,
        # Then add a space before the embed link / after the pre-existing link
        $.after a, embed
        $.after a, $.tn ' '

      # track the insertion point,
      p = m.index+lLen

      # And store leftover content in a text node so we can append it and continue to parse it.
      rest = $.tn(txt.substring(p, txt.length))

      # If there is any content left, we append and parse it.
      unless rest.textContent == ""
        $.after a, rest
        @text rest

  embed: ->
    # We setup the link to be replaced by the embedded video
    link = @.previousSibling.previousSibling

    # We create an iframe to embed
    iframe = $.el 'iframe'
      src: 'http://www.youtube.com/embed/' + @name

    unembed = $.el 'a'
      name:        @name
      href:        'javascript:;'
      textContent: '(unembed)'
    
    $.on unembed, 'click', Linkify.unembed

    # We style the iframe with respectable boundaries.
    iframe.style.border = '0'
    iframe.style.width  = '640px'
    iframe.style.height = '390px'

    # We replace the link with the iframe and kill the embedding element.
    $.replace link, iframe
    $.replace @, unembed
  
  unembed: ->
    embedded = @.previousSibling.previousSibling
    
    a = $.el 'a'
      textContent: embedded.src
      className: 'linkify'
      rel:       'nofollow noreferrer'
      target:    'blank'
      href:      @name
    
    Linkify.concat(a)

    embed = $.el 'a'
      name:         @name
      className:    'embedlink'
      href:         'javascript:;'
      textContent:  '(embed)'

    $.on embed, 'click', Linkify.embed
    
    $.replace embedded, a
    $.replace @, embed

  concat: (a) ->
    $.on a, 'click', (e) ->
      # Shift + CTRL + Click
      if e.shiftKey and e.ctrlKey

        # Let's not accidentally open the link while we're editting it.
        e.preventDefault()
        e.stopPropagation()

        # We essentially check for a <br> and make sure we're not merging non-post content.
        if ("br" == @.nextSibling.tagName.toLowerCase() or "spoiler" == @.nextSibling.className) and @.nextSibling.nextSibling.className != "abbr"
          $.rm @.nextSibling
          child = $.tn(@textContent + @.nextSibling.textContent)
          $.rm @.nextSibling
          Linkify.text(child, @)