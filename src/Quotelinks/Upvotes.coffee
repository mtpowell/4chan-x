Upvotes =
  count: {}
  text: '\u305D\u3046\u3060\u306D'
  regexp: ///
    (?:^>.*\n)+
    (?:
      i
      |top
      |holy
      |shit
      |ay*
      |oh?
      |omg
      |god
      |jesus
      |christ
      |fuck
      |fukken
      |fucking?
      |\s
      |[.,-]
    )*
    (?:
      \u305D\u3046\u3060\u306D
      |this(?!\ )
      |\+1
      |upvote(?!\ )d?
      |under[\ -]?rated
      |\/thread
      |10\/10
      |(?:lol|kek|lel|lmao)(?:'?d|[.!]?$)
      |(?:ha)+[.!]?$
      |saved
      |nice(?!\ )
      |my\ sides
    )
    (?=\b|\W|$)
  ///gmi

  init: ->
    return unless g.VIEW in ['thread', 'index'] and Conf['Upvotes']
    Post.callbacks.push
      name: 'Upvotes'
      cb:   @node

  node: ->
    return if @isFetchedQuote or @origin?.isFetchedQuote

    if @isClone
      @nodes.vote = $ '.upvote', @nodes.info
      $.on @nodes.vote, 'click', Upvotes.vote
      return

    a = $.el 'a',
      className:   'upvote'
      href:        'javascript:;'
      textContent: '+'
    $.add @nodes.info, a
    @nodes.vote = a
    $.on a, 'click', Upvotes.vote

    return unless g.VIEW is 'thread'

    Upvotes.count[@fullID] = 0

    quotes = {}
    for context in @info.comment.match(Upvotes.regexp) or []
      for quote in context.match(/>>\d+/g) or []
        quotes[quote[2..]] = true
    for quote of quotes
      Upvotes.increment "#{g.BOARD}.#{quote}"

  increment: (fullID) ->
    return unless fullID of Upvotes.count
    count = ++Upvotes.count[fullID]
    post = g.posts[fullID]
    for post in [post, post.clones...]
      post.nodes.vote.textContent = "#{Upvotes.text}x#{count}"
    return

  vote: ->
    return unless QR.postingIsEnabled
    $.off QR.nodes.com, 'input', Upvotes.setText if QR.nodes
    QR.quote.call @
    {com} = QR.nodes
    text = "#{Conf['upvoteText']}\n"
    pos = com.selectionStart
    Upvotes.context = com.value[...pos]
    com.value = com.value[...pos] + text + com.value[pos..]
    pos += text.length
    com.setSelectionRange pos, pos
    $.event 'input', null, com
    Upvotes.post = $.id 'selected'
    $.on com, 'input', Upvotes.setText

  setText: ->
    {context} = Upvotes
    if $.id('selected') is Upvotes.post and @value[...context.length] is context
      Conf['upvoteText'] = @value[context.length..].split('\n')[0]
      $.set 'upvoteText', Conf['upvoteText']
    else
      $.off @, 'input', Upvotes.setText
