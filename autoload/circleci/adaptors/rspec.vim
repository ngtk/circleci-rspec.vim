let s:save_cpo = &cpo
set cpo&vim

function! circleci#adaptors#rspec#get_failed_testcases(username, reponame, branch) abort
  let recent_builds = circleci#project#get_recent_builds(a:username, a:reponame, a:branch)
  let latest_build_num = recent_builds[0].build_num
  let artifacts = circleci#project#get_build_artifacts(a:username, a:reponame, latest_build_num)
  let urls = s:extract_rspec_junit_xml_urls(artifacts)

  let failed_testcases = []
  for url in urls
    let failed_testcases += circleci#adaptors#rspec#get_failed_testcases_from_junit_xml_url(url)
  endfor

  return failed_testcases
endfunction

function! circleci#adaptors#rspec#get_failed_testcases_from_junit_xml_url(junit_xml_url) abort
    let param = { 'circle-token':  g:circleci#token }
    let header =
          \ {
          \ 'accept': 'application/xml',
          \ 'content-type': 'application/xml'
          \ }
    let reponse = webapi#http#get(a:junit_xml_url, param, header)
    let content = webapi#xml#parse(reponse.content)
    let testcases = content['child']
    if type(testcases) != type([]) || len(testcases) == 0
      return
    endif

    let failed_testcases = []
    for testcase in testcases
      if type(testcase) == type({})
        let failures = testcase['child']
        if len(failures) != 0
          for failure in failures
            if failure['name'] == 'failure'
              call add(failed_testcases, testcase)
            endif
            unlet failure
          endfor " failures
        endif
        unlet failures
      endif
      unlet testcase
    endfor " testcases

    return failed_testcases
endfunction

function! s:extract_rspec_junit_xml_urls(artifacts) abort
  let urls = []

  for artifact in a:artifacts
    let url = artifact.url
    if url =~ '.*rspec.xml'
      call add(urls, url)
    endif
  endfor

  return urls
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
