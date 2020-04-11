folder-whitelist = (name) ->
  return true

angular.module 'app.controllers' <[ui.router ngCookies]>
.controller AppCtrl: <[$scope $window $state $rootScope $timeout]> ++ ($scope, $window, $state, $rootScope, $timeout) ->
  $scope.$watch '$state.current.name' ->
    $scope.irc-enabled = true if it is \irc

  # mobile
  window.addEventListener "load" ->
    <- $timeout _, 0
    window.scrollTo 0, 1

  <- $timeout _, 10s * 1000ms
  $rootScope.hideGithubRibbon = true

.controller HackFolderCtrl: <[$scope $sce $window $state $cookies $q HackFolder hackId]> ++ ($scope, $sce, $window, $state, $cookies, $q, HackFolder, hackId) ->
  $scope <<< do
    hackId: hackId
    hasViewMode: -> it?match /g(doc|present|draw)/
    sortableOptions: do
      update: -> console?log \notyetupdated
    iframes: HackFolder.iframes
    docs: HackFolder.docs
    tree: HackFolder.tree
    godoc: (doc) ->
      if doc.opts?target == '_blank'
        window.open doc.url, doc.id
        return true
      else if doc.url.match /(https?:)?\/\/[^/]*(github|facebook)\.com/
        window.open doc.url, doc.id
        return true
      else
        $scope.go "/#{ hackId }/#{ decodeURIComponent doc.id }"
    open: (doc) ->
      window.open doc.url, doc.id
      return false
    activate: ->
      doc = HackFolder.activate it
      if doc?type is \hackfoldr
        console?log \folder!!
    saveBtn: void
    saveModalOpts: dialogFade: true
    showSaveModal: (show,rm,e)->
      $ '.ui.modal.save' .modal \toggle, show
      if e => $scope.saveBtn = $ e.target
      if rm =>
        $cookies.savebtn = \consumed
        if $scope.saveBtn => $scope.saveBtn.fadeOut 1000
    showSaveBtn: ->
      $cookies.savebtn != \consumed
    HackFolder: HackFolder
    barframeSrc: (entry) ->
      src = entry.opts.bar.replace /\{(\w+)\}/g, -> entry[&1]
      $sce.trustAsResourceUrl src
    iframeCallback: (doc={}) -> (status) -> $scope.$apply ->
      console?log \iframecb status, doc
      # set current title for phone and tablet view,
      # please also check hack.jade.
      $state.current.title = doc.title
      document.title = "#{doc.title} – hackfoldr" if doc.title
      if status is \fail
        doc.noiframe = true
      else
        doc.noiframe = false
      doc.iframeunsure = true if status is \unsure

    debug: -> console?log it, @
    reload: -> HackFolder.getIndex hackId, true ->

  unless folder-whitelist hackId
    return $window.location.href = "http://hackfoldr.org/#{$window.location.pathname}"

  $scope.$watch '$state.params.docId' (docId) ->
    $scope.docId = encodeURIComponent docId if docId
  loaded = $q.defer!
  loaded.promise.then -> $scope.$watch 'docId' (docId) ->
    if docId?
      if $state.params.docId is $scope.first?id
        $state.transitionTo 'hack.doc', { docId: "", hackId }
    else
      if $scope.first?id
        $scope.docId ?= that
        $state.transitionTo 'hack.doc', { docId: "", hackId }
        return
    doc = HackFolder.activate docId if docId
    if doc?type is \hackfoldr
      $scope.show-index = true
      folder-title, docs, tree <- HackFolder.load-remote-csv doc.id
      [entry] = [entry for entry in HackFolder.tree when entry.id is docId]
      entry.tagFilter = entry.tags?0?content
      unless entry.children
        entry.children ?= tree?0.children
        HackFolder.docs.splice docs.length, 0, ...docs
      $scope.indexDocs = docs
      $scope.indexSearch = hackId.replace /^g0v-/,''
    else
      $scope.show-index = false
  $scope.show-index = $state.current.name is \hack.index
  return if $scope.show-index

  $scope.collapsed = $cookies.collapsed ? $window.innerWidth < 768
  $scope.collapsed = false if $scope.collapsed is 'false'

  $scope.$watch 'collapsed' -> if it?
    $cookies.collapsed = !!it

  $scope.sidebar = false
  $scope.toggleSidebar = ->
    $scope.collapsed = false
    $scope.sidebar = !$scope.sidebar
  <- HackFolder.getIndex hackId, false
  <- $scope.$safeApply $scope
  [$scope.first] = [d for d in HackFolder.docs when d.url]
  loaded.resolve!

.directive 'resize' <[$window]> ++ ($window) ->
  (scope, element, attrs) ->
    refresh-size = ->
      scope.width = $window.innerWidth
      scope.height = $window.innerHeight
      scope.content-height = $window.innerHeight - $ element .offset!top

    angular.element $window .bind 'resize' ->
      scope.$apply refresh-size

    refresh-size!

.directive 'ngxIframe' <[$parse]> ++ ($parse) ->
  link: ($scope, element, attrs) ->
    cb = ($parse attrs.ngxIframe) $scope
    dispatch = (iframe, loading) ->
      ok = !try
        iframe.location ~= \about:blank
      # access denied, meaning the iframe is loaded. wait for .load to fire
      if loading and $.browser.mozilla
        # check if the failure is actually XFO denied. this doesn't work
        # req = $.ajax do
        #   type: \OPTION
        #   url: attrs.src
        #   success: ->
        #     console.log \done
        #     req.getAllResponseHeaders!
        #   error: (request, textStatus, errorThrown) ->
        #     console.log \err textStatus, request.getAllResponseHeaders!
        #     console.log request
        cb \unsure
      else
        cb if ok => \ok else \fail

    var fail
    $ element .load ->
      clearTimeout fail
      dispatch @contentWindow, true

    fail = setTimeout (->
      dispatch element[0].contentWindow
    ), 5000ms
.directive \ngxNoclick ->
  ($scope, element, attrs) ->
    $ element .click -> it.preventDefault!; false

.directive 'ngxClickMeta' <[$parse]> ++ ($parse) ->
  link: ($scope, element, attrs) ->
    cb = $parse attrs.ngxClickMeta

    is-meta = if navigator.appVersion.match /(Win|X11)/
      -> it.ctrlKey
    else
      -> it.metaKey

    $ element .click (e) ->
      if is-meta e
        unless cb $scope
          e.preventDefault!
          return false
      return

.directive \ngxFinal ->
  ($scope, element, attrs) ->
    $ element .click -> it.stopPropagation();

.directive \scrollbar <[$window]> ++ ($window) ->
  (scope, element, attrs) ->
    has-scrollbar = ->
      $index = $('.index')
      scope.has-scrollbar = $index.get(0).scrollHeight > $window.innerHeight - $('.ui.menu').height()
    angular.element $window .bind \resize ->
      scope.$apply has-scrollbar
    scope.$watch 'docs' has-scrollbar
    has-scrollbar()

.factory HackFolder: <[$http $sce]> ++ ($http, $sce) ->
  iframes = {}
  docs = []
  tree = []
  var hackId
  self = do
    iframes: iframes
    docs: docs
    tree: tree
    activate: (id, edit=false) ->
      [doc] = [d for d in docs when d.id is id]
      type = doc?type
      for t in tree
        if t?children?map (.id)
          t.expand = true if id in that
      mode = if edit => \edit else \view
      src = match type
      | \gdoc =>
          "https://docs.google.com/document/d/#id/#mode?pli=1&overridemobile=true"
      | \gsheet =>
          "https://docs.google.com/spreadsheet/ccc?key=#id"
      | \gpresent =>
          "https://docs.google.com/presentation/d/#id/#mode"
      | \gdraw =>
          "https://docs.google.com/drawings/d/#id/#mode"
      | \gsheet =>
          "https://docs.google.com/spreadsheet/ccc?key=#id"
      | \hackpad =>
        "https://#{ doc.site ? '' }hackpad.com/#{id}"
      | \ethercalc =>
          "https://ethercalc.org/#id"
      | \video =>
          if doc.provider is \youtube
              "https://www.youtube.com/embed/#{id}"
          else if doc.provider is \ustream
              "http://www.ustream.tv/embed/#{id}?v=3"
      | \url => decodeURIComponent decodeURIComponent id
      | otherwise => ''

      src += doc?hashtag if doc?hashtag

      src = $sce.trustAsResourceUrl src if src
      return doc if doc?type is \hackfoldr
      if iframes[id]
          that <<< {src, mode}
      else
          iframes[id] = {src, doc, mode}
      return doc

    getIndex: (id, force, cb) ->
      return cb docs if hackId is id and !force

      if local-storage[id] and !force
        csv = try JSON.parse local-storage[id]
        if csv
          hackId := id
          folder-title, docs <- @load-csv csv, docs, tree
          self.folder-title = folder-title
          cb docs

      # TODO: This should obtain the redirected ID from A1
      # See: https://github.com/hackfoldr/hackfoldr-2.0/issues/16
      const EthercalcToGoogleDocMap = {
        'Kaohsiung-explode-20140801': '1WVWrKC-Tbry3ltgouQPpZH2Cd2HkKeZ8DjLs4PWa1z4'
      }

      retry = 0
      if (EthercalcToGoogleDocMap[id] || id) is /^[-\w]{40}[-\w]*$/ then doit = ~>
        callback = ~> for own k, sheet of it
          docs.length = 0
          hackId := id
          csv = sheet.to-array!
          @process-csv csv, id, cb
          return
        Tabletop.init { key: (EthercalcToGoogleDocMap[id] || id), callback, -simpleSheet }
      else doit = ~>
        csv <~ $http.get "https://ethercalc.org/_/#{id}/csv"
        .error -> return if ++retry > 3; setTimeout doit, 1000ms
        .success

        hackId := id
        docs.length = 0
        @process-csv csv, id, cb
      doit!


    process-csv: (csv, id, cb) ->
      if typeof csv is \string
        csv -= /^\"?#.*\n/gm
        csv = CSV.parse(csv)
      local-storage[id] = JSON.stringify csv
      folder-title, docs <- @load-csv csv, docs, tree
      self.folder-title = folder-title
      cb docs

    load-remote-csv: (id, cb) ->
      csv <~ $http.get "https://ethercalc.org/_/#{id}/csv"
      .success
      docs = []
      tree = []
      folder-title <~ @load-csv csv, docs, tree
      cb folder-title, docs, tree

    load-csv: (csv, docs, tree, cb) ->
      data = csv
      var folder-title
      folder-opts = {}
      entries = for line in data | line?length
        [url, title, opts, tags, summary, ...rest] = line
        continue unless title
        title -= /^"|"$/g
        opts -= /^"|"$/g if opts
        if opts
          opts = try JSON.parse opts.replace /""/g '"'
        opts ?= {}
        tags -= /^"|"$/g if tags
        matched = url.match /^"?(\s*)(\S+?)?(#\S+?)?\s*"?$/
        continue unless matched?length
        [_, prefix, url, hashtag] = matched
        entry = { summary, hashtag, url, title, indent: prefix.length, opts: {} <<< folder-opts <<< opts } <<< match url
        | void
            unless folder-title
              if title
                folder-title = title
                title = null
              if opts
                folder-opts = opts
            title: title
            type: \dummy
            id: \dummy
        | // ^\/\/(.*?)(?:\#(.*))?$ //
            type: \hackfoldr
            id: that.1
            tag: that.2
        | // ^https?:\/\/www\.ethercalc\.(?:com|org)/(.*) //
            type: \ethercalc
            id: that.1
        | // https:\/\/docs\.google\.com/document/(?:d/)?([^/]+)/ //
            type: \gdoc
            id: that.1
        | // https:\/\/docs\.google\.com/spreadsheet/ccc\?key=([^/?&]+) //
            type: \gsheet
            id: that.1
        | // https:\/\/docs\.google\.com/drawings/(?:d/)?([^/]+)/ //
            type: \gdraw
            id: that.1
        | // https:\/\/docs\.google\.com/presentation/(?:d/)?([^/]+)/ //
            type: \gpresent
            id: that.1
        | // https?:\/\/(\w+\.)?hackpad\.com/(?:.*?-)?([\w]+)(\#.*)?$ //
            type: \hackpad
            site: that.1
            id: that.2
        | // https?:\/\/(?:youtu\.be/|(?:www\.)?youtube\.com/(?:embed/|watch\?v=))([-\w]+) //
            type: \video
            provider: \youtube
            id: that.1
            icon: "https://www.google.com/s2/favicons?domain=#{ url }"
        | // https?:\/\/(?:www\.)?ustream\.tv/(?:embed|channel)/([-\w]+) //
            type: \video
            provider: \ustream
            id: that.1
            icon: "https://www.google.com/s2/favicons?domain=#{ url }"
        | // ^(https?:\/\/[^/]+) //
            type: \url
            id: encodeURIComponent encodeURIComponent url
            icon: "https://www.google.com/s2/favicons?domain=#{ that.1 }"
        | otherwise => console?log \unrecognized url

        if entry.type is \dummy and !entry.title?length
          null
        else
          {icon: "/img/#{ entry.type }.png"} <<< entry <<< do
            tags: (entry.opts?tags ? []) ++ ((tags?split \,) ? [])
              .filter -> it.length
              .map (tag) ->
                [_, content, c, ...rest] = tag.match /^(.*?)(?::(.*))?$/
                {content, class: c ? 'warning'}

      # check live status of youtube or ustream
      entries.filter (?url) .map ->
        if it.type is 'video' and it.provider is 'youtube'
          request = gapi.client.youtube.videos.list({'id': it.id, 'part':'snippet'})
          response <~ request.execute()
          if 'live' == response.items?[0].snippet.liveBroadcastContent
            it.tags ++= {class: 'warning', content: 'LIVE'}
        else if videoToken = it.url.match(/ustream.tv\/embed\/([^?]+)/)
          videoId = videoToken[1]
          response <- $.get ("http://query.yahooapis.com/v1/public/yql?q=select%20*%20from%20html%20where%20url%3D'http%3A%2F%2Fapi.ustream.tv%2Fjson%2Fchannel%2F" + videoId + "%2FgetValueOf%2Fstatus'&format=json&diagnostics=true&callback=")
          if 'live' == JSON.parse(response.query?.results?.body?.p).results
            it.tags ++= {class: 'warning', content: 'LIVE'}
      docs.splice 0, docs.length, ...(entries.filter -> it?)
      last-parent = 0
      nested = for entry, i in docs
        if i > 0 and entry.indent
          docs[last-parent]
            ..children ?= []
              ..push entry
          null
        else
          last-parent = i
          entry
      nested .= filter -> it?
      nested .= map ->
        if it.children
          it.expand = it.opts?expand ? it.children.length < 5
        it
      tree.splice 0, tree.length, ...nested
      cb folder-title, docs

.directive \ngxTooltip ->
  ($scope, element, attrs) ->
    $ element .popup do
      position: "right center"
      duration: 1ms # the popup will not close if you set this to 0
