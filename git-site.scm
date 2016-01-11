(use irregex matchable git spiffy clojurian-syntax posix
     (only intarweb request-uri) uri-common sxml-serializer)

(define cla command-line-arguments)

;; spiffy default is application/octet-stream which will trigger
;; download dialog in your browser. I think this is oftern annoying
;; for files without extensions.
(default-mime-type 'text/plain)

(define repo-path (make-parameter #f))
(match (cla)
  (() (print "usage: <repo> [port]") (exit 0))
  ((repo port)
   (repo-path repo)
   (server-port (string->number port)))
  ((repo) (repo-path repo)))


;; ==================== error handling ====================
;; reference not found. TODO: remove refs/tags refs/heads prefix for
;; less confusion.
(define (rnf-error-message repo ref pathnaem)
  (serialize-sxml
   `(html5 (headers (meta (@ (charset "utf-8"))))
           (body (h3 "repository reference \"" ,ref "\" not found")
                 (ul ,@(map (lambda (r) `(li ,(cleanup-reference (reference-name r))))
                            (references repo)))))))

;; print something that's useful for debugging and actually finding
;; what you were looking for. directory listing is nice.
(define (fnf-error-message repo ref pathname)
  (serialize-sxml
   `(html5 (headers (meta (@ (charset "utf-8"))))
           (body (div (span (@ (style "font-size: 150%;")) "404 File not found")
                      (span "\"" ,pathname "\" not in " ,ref "\n\n"))
                 (ul ,@(map (lambda (pathname)
                              `(li (a (@ (href ,(conc "/" ref "/" pathname))) ,pathname)))
                            (entries repo ref)))))))

;; ==================== everything else ====================

;; (repo-path "/tmp/g/.git/")
(define repo (repository-open (repo-path) #t))

;; look for branchname r first. then try tags. errors if ref not found
;; in tags/branches.
(define (reference* repo r)
  (condition-case
   (reference repo (conc "refs/heads/" r))
   ((exn git) (reference repo (conc "refs/tags/" r)))))


(define (pathname-tree repo strref pathname)
  (->> (reference* repo strref)
       (reference-resolve)
       (commit repo)
       (commit-tree)))

;; (file-blob repo  "refs/heads/master" "folder/file")
(define (file-blob repo strref pathname)
  (define (assert-file te)
    (if (eq? 'blob (tree-entry-type te)) te (abort (make-property-condition 'fnf))))
  (->> (or (tree-ref (pathname-tree repo strref pathname) pathname)
           (abort (make-property-condition 'fnf)))
       (assert-file) ;; 404 for directory listings
       (tree-entry->object)
       (blob-content)
       (blob->string)))

;;(entries repo "master")
(define (entries repo ref)
  (map
   (lambda (pair) (conc (car pair) (tree-entry-name (cdr pair))))
   (filter ;; don't show directories
    (lambda (pair) (eq? 'blob (tree-entry-type (cdr pair))))
    (tree-entries (commit-tree (commit repo (reference* repo ref)))))))

;; (cleanup-reference "refs/heads/master") => "master"
(define (cleanup-reference str)
  (->> (irregex-replace `(: "refs/tags/") str)
       (irregex-replace `(: "refs/heads/"))))

(define (handler c)
  ;; (set! R(current-request)) (current-request R)
  (match (uri-path (request-uri (current-request)))
    ;; this is pretty hacky, but chicken-git doesnt give us `fetch`
    ;; procedures.
    (('/ "_fetch")
     (send-response body: (with-input-from-pipe
                           (conc "cd " (repo-path) " && git fetch --all")
                           read-string)))
    (('/ ref pathnames ...)
     (let*-values (((pathname) (string-join pathnames "/"))
                   ((dir file ext) (decompose-pathname pathname)))
       (condition-case
        (send-response body: (file-blob repo ref pathname)
                       headers: `((content-type ,(file-extension->mime-type ext))))
        ((exn git) (send-response status: 'not-found
                                  body: (rnf-error-message repo ref pathname)))
        ((fnf) (send-response status: 'not-found
                              body: (fnf-error-message repo ref pathname))))))))

(define server-thread
  (thread-start!
   (lambda ()
     (vhost-map `((".*" . ,(lambda (c) (handler c)))))
     (start-server))))

(thread-join! server-thread)

