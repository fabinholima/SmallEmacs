;;; -*- lexical-binding: t -*-

(defvar bootstrap-version)
(let ((bootstrap-file
       (expand-file-name "straight/repos/straight.el/bootstrap.el" user-emacs-directory))
      (bootstrap-version 5))
  (unless (file-exists-p bootstrap-file)
    (with-current-buffer
        (url-retrieve-synchronously
         "https://raw.githubusercontent.com/raxod502/straight.el/develop/install.el"
         'silent 'inhibit-cookies)
      (goto-char (point-max))
      (eval-print-last-sexp)))
      (load bootstrap-file nil 'nomessage))

(straight-use-package 'use-package)
(eval-when-compile (require 'use-package))

(setq my/remote-server
      (or (string= (getenv "IS_REMOTE") "true")
          (string= (system-name) "dev-digital")
          (string= (system-name) "viridian")))

(setq my/is-termux (string-match-p (rx (* nonl) "com.termux" (* nonl)) (getenv "HOME")))

(defun my/system-name ()
  (or (getenv "ANDROID_NAME")
      (system-name)))

(setq my/nested-emacs (and (getenv "IS_EMACS") t))
(setenv "IS_EMACS" "true")

(setq my/emacs-started nil)

(add-hook 'emacs-startup-hook
          (lambda ()
            (message "*** Emacs loaded in %s with %d garbage collections."
                     (format "%.2f seconds"
                             (float-time
                              (time-subtract after-init-time before-init-time)))
                     gcs-done)
            (setq my/emacs-started t)))

(setq use-package-verbose nil)

(setq use-package-compute-statistics t)

(setq gc-cons-threshold 80000000)
(setq read-process-output-max (* 1024 1024))

(add-hook 'emacs-startup-hook
          (lambda ()
            (if (boundp 'after-focus-change-function)
                (add-function :after after-focus-change-function
                              (lambda ()
                                (unless (frame-focus-state)
                                  (garbage-collect))))
              (add-hook 'after-focus-change-function 'garbage-collect))))

(defun my/get-ram-usage-async (callback)
  (let* ((temp-buffer (generate-new-buffer "*ps*"))
         (proc (start-process "ps" temp-buffer "ps"
                              "-p" (number-to-string (emacs-pid)) "-o" "rss")))
    (set-process-sentinel
     proc
     (lambda (process _msg)
       (when (eq (process-status process) 'exit)
         (let* ((output (with-current-buffer temp-buffer
                          (buffer-string)))
                (usage (string-to-number (nth 1 (split-string output "\n")))))
           (ignore-errors
             (funcall callback usage)))
         (kill-buffer temp-buffer))))))

(defun my/ram-usage ()
  (interactive)
  (my/get-ram-usage-async
   (lambda (data)
     (message "%f Gb" (/ (float data) 1024 1024)))))




;(use-package exec-path-from-shell
;  :straight t)

;; TO MAC OS X
;;(when (memq window-system '(mac ns x))
;;  (exec-path-from-shell-initialize))


;; TO LINUX

;(when (daemonp)
;  (exec-path-from-shell-initialize))

;(exec-path-from-shell-copy-env "PATH")

(use-package micromamba
  :straight t
  :if (executable-find "micromamba")
  :config
  (micromamba-activate "general"))

(setq custom-file (concat user-emacs-directory "custom.el"))
(load custom-file 'noerror)

(setq auth-source-debug nil)
(setq auth-sources '("~/.authinfo.gpg"))

(let ((private-file (expand-file-name "private.el" user-emacs-directory)))
  (when (file-exists-p private-file)
    (load-file private-file)))

(use-package no-littering
  :straight t)

(defun my/run-in-background (command)
  (let ((command-parts (split-string command "[ ]+")))
    (apply #'call-process `(,(car command-parts) nil 0 nil ,@(cdr command-parts)))))

(defun my/quit-window-and-buffer ()
  (interactive)
  (quit-window t))

(setq confirm-kill-emacs 'y-or-n-p)

(setq initial-major-mode 'fundamental-mode)
(setq initial-scratch-message "Hello there <3\n\n")


(use-package general
  :straight t
  :config
  (general-evil-setup))

(use-package which-key
  :config
  (setq which-key-idle-delay 0.3)
  (setq which-key-popup-type 'frame)
  (which-key-mode)
  (which-key-setup-side-window-bottom)
  (set-face-attribute 'which-key-local-map-description-face nil
                      :weight 'bold)
  :straight t)

(defun my/dump-bindings-recursive (prefix &optional level buffer)
  (dolist (key (which-key--get-bindings (kbd prefix)))
    (with-current-buffer buffer
      (when level
        (insert (make-string level ? )))
      (insert (apply #'format "%s%s%s\n" key)))
    (when (string-match-p
           (rx bos "+" (* nonl))
           (substring-no-properties (elt key 2)))
      (my/dump-bindings-recursive
       (concat prefix " " (substring-no-properties (car key)))
       (+ 2 (or level 0))
       buffer))))

(defun my/dump-bindings (prefix)
  "Dump keybindings starting with PREFIX in a tree-like form."
  (interactive "sPrefix: ")
  (let ((buffer (get-buffer-create "bindings")))
    (with-current-buffer buffer
      (erase-buffer))
    (my/dump-bindings-recursive prefix 0 buffer)
    (with-current-buffer buffer
      (goto-char (point-min))
      (setq-local buffer-read-only t))
    (switch-to-buffer-other-window buffer)))

(use-package evil
  :straight t
  :init
  (setq evil-want-integration t)
  (setq evil-want-C-u-scroll t)
  (setq evil-want-keybinding nil)
  (setq evil-search-module 'evil-search)
  (setq evil-split-window-below t)
  (setq evil-vsplit-window-right t)
  (unless (display-graphic-p)
    (setq evil-want-C-i-jump nil))
  :config
  (evil-mode 1)
  ;; (setq evil-respect-visual-line-mode t)
  (when (fboundp #'undo-tree-undo)
    (evil-set-undo-system 'undo-tree))
  (when (fboundp #'general-define-key)
    (general-define-key
     :states '(motion))))

(use-package evil-surround
  :straight t
  :after evil
  :config
  (global-evil-surround-mode 1))

(use-package evil-commentary
  :straight t
  :after evil
  :config
  (evil-commentary-mode))

(use-package evil-quickscope
  :straight t
  :after evil
  :config
  :hook ((prog-mode . turn-on-evil-quickscope-mode)
         (LaTeX-mode . turn-on-evil-quickscope-mode)
         (org-mode . turn-on-evil-quickscope-mode)))

(use-package evil-numbers
  :straight t
  :commands (evil-numbers/inc-at-pt evil-numbers/dec-at-pt)
  :init
  (general-nmap
    "g+" 'evil-numbers/inc-at-pt
    "g-" 'evil-numbers/dec-at-pt))

(use-package evil-lion
  :straight t
  :config
  (setq evil-lion-left-align-key (kbd "g a"))
  (setq evil-lion-right-align-key (kbd "g A"))
  (evil-lion-mode))

(use-package evil-matchit
  :straight t
  :disabled
  :config
  (global-evil-matchit-mode 1))

(defun my/evil-ex-search-word-forward-other-window (count &optional symbol)
  (interactive (list (prefix-numeric-value current-prefix-arg)
                     evil-symbol-word-search))
  (save-excursion
    (evil-ex-start-word-search nil 'forward count symbol))
  (other-window 1)
  (evil-ex-search-next))

(general-define-key
 :states '(normal)
 "&" #'my/evil-ex-search-word-forward-other-window)

(use-package evil-collection
  :straight t
  :after evil
  :config
  (evil-collection-init
   '(eww devdocs proced emms pass calendar dired debug guix calc
         docker ibuffer geiser pdf info elfeed edebug bookmark company
         vterm flycheck profiler cider explain-pause-mode notmuch custom
         xref eshell helpful compile comint git-timemachine magit prodigy
         slime forge deadgrep vc-annonate telega doc-view gnus outline)))

(defun minibuffer-keyboard-quit ()
  "Abort recursive edit.
In Delete Selection mode, if the mark is active, just deactivate it;
then it takes a second \\[keyboard-quit] to abort the minibuffer."
  (interactive)
  (if (and delete-selection-mode transient-mark-mode mark-active)
      (setq deactivate-mark  t)
    (when (get-buffer "*Completions*") (delete-windows-on "*Completions*"))
    (abort-recursive-edit)))

(defun my/escape-key ()
  (interactive)
  (evil-ex-nohighlight)
  (keyboard-quit))

(general-define-key
 :keymaps '(normal visual global)
 [escape] #'my/escape-key)

(general-define-key
 :keymaps '(minibuffer-local-map
            minibuffer-local-ns-map
            minibuffer-local-completion-map
            minibuffer-local-must-match-map
            minibuffer-local-isearch-map)
 [escape] 'minibuffer-keyboard-quit)

 (general-def :states '(normal insert visual)
  "<home>" 'beginning-of-line
  "<end>" 'end-of-line)

; (general-create-definer my-leader-def
;   :keymaps 'override
;   :prefix "SPC"
;   :states '(normal motion emacs))

; (general-def :states '(normal motion emacs)
;   "SPC" nil
;   "M-SPC" (general-key "SPC"))

; (general-def :states '(insert)
;   "M-SPC" (general-key "SPC" :state 'normal))

; (my-leader-def "?" 'which-key-show-top-level)
; (my-leader-def "E" 'eval-expression)

; (general-def :states '(insert)
;   "<f1> e" #'eval-expression)

; (my-leader-def
;   "a" '(:which-key "apps"))

; (general-def
;   :keymaps 'universal-argument-map
;   "M-u" 'universal-argument-more)
; (general-def
;   :keymaps 'override
;   :states '(normal motion emacs insert visual)
;   "M-u" 'universal-argument)

; (my-leader-def
;   :infix "P"
;   "" '(:which-key "profiler")
;   "s" 'profiler-start
;   "e" 'profiler-stop
;   "p" 'profiler-report)

(general-define-key
  :keymaps 'override
  "C-<right>" 'evil-window-right
  "C-<left>" 'evil-window-left
  "C-<up>" 'evil-window-up
  "C-<down>" 'evil-window-down
  "C-h" 'evil-window-left
  "C-l" 'evil-window-right
  "C-k" 'evil-window-up
  "C-j" 'evil-window-down
  "C-x h" 'previous-buffer
  "C-x l" 'next-buffer)

; (general-define-key
;  :keymaps 'evil-window-map
;  "x" 'kill-buffer-and-window
;  "d" 'kill-current-buffer)

; (winner-mode 1)

(general-define-key
 :keymaps 'evil-window-map
 "u" 'winner-undo
 "U" 'winner-redo)

; (defun my/lisp-interaction-buffer ()
;   (interactive)
;   (let ((buf (get-buffer-create "*lisp-interaction*")))
;     (with-current-buffer buf
;       (lisp-interaction-mode))
;     (switch-to-buffer buf)))

; (my-leader-def
;   :infix "b"
;   "" '(:which-key "buffers")
;   "s" '(my/lisp-interaction-buffer
;         :which-key "*lisp-interaction*")
;   "m" '((lambda () (interactive) (persp-switch-to-buffer "*Messages*"))
;         :which-key "*Messages*")
;   "l" 'next-buffer
;   "h" 'previous-buffer
;   "k" 'kill-buffer
;   ;; "b" 'persp-ivy-switch-buffer
;   "b" #'persp-switch-to-buffer*
;   "r" 'revert-buffer
;   "u" 'ibuffer)

; (general-nmap
;   "gD" 'xref-find-definitions-other-window
;   "gr" 'xref-find-references
;   "gd" 'evil-goto-definition)

; (my-leader-def
;   "fx" 'xref-find-apropos)

; (use-package xref
;   :straight (:type built-in))

; (require 'hideshow)
; (general-define-key
;  :keymaps '(hs-minor-mode-map outline-minor-mode-map outline-mode-map)
;  :states '(normal motion)
;  "TAB" 'evil-toggle-fold)

(defun my/zoom-in ()
  "Increase font size by 10 points"
  (interactive)
  (set-face-attribute 'default nil
                      :height
                      (+ (face-attribute 'default :height) 10)))

(defun my/zoom-out ()
  "Decrease font size by 10 points"
  (interactive)
  (set-face-attribute 'default nil
                      :height
                      (- (face-attribute 'default :height) 10)))

;; change font size, interactively
(global-set-key (kbd "C-+") 'my/zoom-in)
(global-set-key (kbd "C-=") 'my/zoom-out)

; (when (and my/is-termux (not (equal (my/system-name) "snow")))
;   (define-key key-translation-map (kbd "`") (kbd "<escape>"))
;   (define-key key-translation-map (kbd "<escape>") (kbd "`")))

; (when my/is-termux
;   (setq split-width-threshold 90))

; (unless (or my/remote-server my/nested-emacs)
;   (add-hook 'after-init-hook #'server-start))

; (defmacro i3-msg (&rest args)
;   `(start-process "emacs-i3-windmove" nil "i3-msg" ,@args))

; (defun my/emacs-i3-windmove (dir)
;   (let ((other-window (windmove-find-other-window dir)))
;     (if (or (null other-window) (window-minibuffer-p other-window))
;         (i3-msg "focus" (symbol-name dir))
;       (windmove-do-window-select dir))))

; (defun my/emacs-i3-direction-exists-p (dir)
;   (cl-some (lambda (dir)
;           (let ((win (windmove-find-other-window dir)))
;             (and win (not (window-minibuffer-p win)))))
;         (pcase dir
;           ('width '(left right))
;           ('height '(up down)))))

; (defun my/emacs-i3-move-window (dir)
;   (let ((other-window (windmove-find-other-window dir))
;         (other-direction (my/emacs-i3-direction-exists-p
;                           (pcase dir
;                             ('up 'width)
;                             ('down 'width)
;                             ('left 'height)
;                             ('right 'height)))))
;     (cond
;      ((and other-window (not (window-minibuffer-p other-window)))
;       (window-swap-states (selected-window) other-window))
;      (other-direction
;       (evil-move-window dir))
;      (t (i3-msg "move" (symbol-name dir))))))

; (defun my/emacs-i3-resize-window (dir kind value)
;   (if (or (one-window-p)
;           (not (my/emacs-i3-direction-exists-p dir)))
;       (i3-msg "resize" (symbol-name kind) (symbol-name dir)
;               (format "%s px or %s ppt" value value))
;     (setq value (/ value 2))
;     (pcase kind
;       ('shrink
;        (pcase dir
;          ('width
;           (evil-window-decrease-width value))
;          ('height
;           (evil-window-decrease-height value))))
;       ('grow
;        (pcase dir
;          ('width
;           (evil-window-increase-width value))
;          ('height
;           (evil-window-increase-height value)))))))

; (use-package transpose-frame
;   :straight t
;   :commands (transpose-frame))

; (defun my/emacs-i3-integration (command)
;   (pcase command
;     ((rx bos "focus")
;      (my/emacs-i3-windmove
;       (intern (elt (split-string command) 1))))
;     ((rx bos "move")
;      (my/emacs-i3-move-window
;       (intern (elt (split-string command) 1))))
;     ((rx bos "resize")
;      (my/emacs-i3-resize-window
;        (intern (elt (split-string command) 2))
;        (intern (elt (split-string command) 1))
;        (string-to-number (elt (split-string command) 3))))
;     ("layout toggle split" (transpose-frame))
;     ("split h" (evil-window-split))
;     ("split v" (evil-window-vsplit))
;     ("kill" (evil-quit))
;     (- (i3-msg command))))

; (use-package aggressive-indent
;   :commands (aggressive-indent-mode)
;   :straight t)

; (setq my/trailing-whitespace-modes '(markdown-mode))

; (require 'cl-extra)

; (add-hook 'before-save-hook
;           (lambda ()
;             (unless (cl-some #'derived-mode-p my/trailing-whitespace-modes)
;               (delete-trailing-whitespace))))
;  
(setq tab-always-indent nil)

(setq-default default-tab-width 4)
(setq-default tab-width 4)
(setq-default evil-indent-convert-tabs nil)
(setq-default indent-tabs-mode nil)
(setq-default evil-shift-round nil)

(setq scroll-conservatively scroll-margin)
(setq scroll-step 1)
(setq scroll-preserve-screen-position t)
(setq scroll-error-top-bottom t)
(setq mouse-wheel-progressive-speed nil)
(setq mouse-wheel-inhibit-click-time nil)

(setq select-enable-clipboard t)
(setq mouse-yank-at-point t)

(setq backup-inhibited t)
(setq auto-save-default nil)

; (use-package undo-tree
;   :straight t
;   :config
;   (global-undo-tree-mode)
;   (evil-set-undo-system 'undo-tree)
;   (setq undo-tree-visualizer-diff t)
;   (setq undo-tree-visualizer-timestamps t)
;   (setq undo-tree-auto-save-history nil)

;   ;(my-leader-def "u" 'undo-tree-visualize)
;   (fset 'undo-auto-amalgamate 'ignore)
;   (setq undo-limit 6710886400)
;   (setq undo-strong-limit 100663296)
;   (setq undo-outer-limit 1006632960))

(use-package yasnippet-snippets
  :disabled
  :straight t)

(use-package yasnippet
  :straight t
  :config
  (setq yas-snippet-dirs
        `(,(concat (expand-file-name user-emacs-directory) "snippets")
          ;; yasnippet-snippets-dir
          ))
  (setq yas-triggers-in-field t)
  (yas-global-mode 1)
  ; (my-leader-def
  ;   :keymaps 'yas-minor-mode-map
  ;   :infix "es"
  ;   "" '(:wk "yasnippet")
  ;   "n" #'yas-new-snippet
  ;   "s" #'yas-insert-snippet
  ;   "v" #'yas-visit-snippet-file)
  )

; (general-imap "M-TAB" 'company-yasnippet)

; (setq default-input-method "russian-computer")

; (defun my/toggle-input-method ()
;   (interactive)
;   (if (derived-mode-p 'exwm-mode)
;       (my/run-in-background "xkb-switch -n")
;     (if (or
;          (not (executable-find "xkb-switch"))
;          (equal (string-trim
;                  (shell-command-to-string "xkb-switch -p"))
;                 "us"))
;         (toggle-input-method)
;       (my/run-in-background "xkb-switch -s us"))))

; (general-define-key
;  :keymaps 'global
;  "M-\\" #'my/toggle-input-method)

; (use-package smartparens
;   :straight t)

(use-package visual-fill-column
  :straight t
  :commands (visual-fill-column-mode)
  :config
  ;; How did it get here?
  ;; (add-hook 'visual-fill-column-mode-hook
  ;;           (lambda () (setq visual-fill-column-center-text t)))
  )

; (defvar my/default-accents
;   '((a . ä)
;     (o . ö)
;     (u . ü)
;     (s . ß)
;     (A . Ä)
;     (O . Ö)
;     (U . Ü)
;     (S . ẞ)))

; (defun my/accent (arg)
;   (interactive "P")
;   (require 'accent)
;   (message "%s" arg)
;   (let* ((after? (eq accent-position 'after))
;          (char (if after? (char-after) (char-before)))
;          (curr (intern (string char)))
;          (default-diac (cdr (assoc curr my/default-accents))))
;     (if (and default-diac (not arg))
;         (progn
;           (delete-char (if after? 1 -1))
;           (insert (format "%c" default-diac)))
;       (call-interactively #'accent-company))))

; (use-package accent
;   :straight (:host github :repo "eliascotto/accent")
;   :init
;   (general-define-key
;    :states '(normal)
;    "gs" #'accent-company)
;   (general-define-key
;    :states '(normal insert)
;    "M-n" #'my/accent)
;   :commands (accent-menu)
;   :config
;   (general-define-key
;    :keymaps 'popup-menu-keymap
;    "C-j" #'popup-next
;    "C-k" #'popup-previous
;    "M-j" #'popup-next
;    "M-k" #'popup-previous)
;   (setq accent-custom '((a (ā))
;                         (A (Ā)))))

; (use-package projectile
;   :straight t
;   :config
;   (projectile-mode +1)
;   (setq projectile-project-search-path '("~/Code" "~/Documents"))
;   (general-define-key
;     :keymaps 'projectile-command-map
;     "b" #'consult-project-buffer))

; (my-leader-def
;   "p" '(:keymap projectile-command-map :which-key "projectile"))

; (general-nmap "C-p" #'projectile-find-file)

(use-package magit
  :straight t
  :commands (magit-status magit-file-dispatch)
  :init
  ; (my-leader-def
  ;   "m" 'magit
  ;   "M" 'magit-file-dispatch)
  :config
  (require 'forge)
  (setq magit-blame-styles
        '((headings
           (heading-format . "%-20a %C %s\n"))
          (highlight
           (highlight-face . magit-blame-highlight))
          (lines
           (show-lines . t)
           (show-message . t)))))

(use-package git-gutter
  :straight t
  :config
  (global-git-gutter-mode +1))

(use-package git-timemachine
  :straight t
  :commands (git-timemachine))

; (use-package difftastic
;   :straight t
;   :commands (difftastic-magit-diff
;              difftastic-magit-show
;              difftastic-files
;              difftastic-buffers)
;   :init
;   (with-eval-after-load 'magit-diff
;     (transient-append-suffix 'magit-diff '(-1 -1)
;       [("D" "Difftastic diff (dwim)" difftastic-magit-diff)
;        ("S" "Difftastic show" difftastic-magit-show)])
;     (general-define-key
;      :keymaps 'magit-blame-read-only-mode-map
;      :states 'normal
;      "D" #'difftastic-magit-show
;      "S" #'difftastic-magit-show))
;   :config
;   (setq difftastic-executable (executable-find "difft"))
;   (general-define-key
;    :keymaps 'difftastic-mode-map
;    :states '(normal)
;    "gr" #'difftastic-rerun
;    "q" #'kill-buffer-and-window))

; (defun my/difftastic-pop-at-bottom (buffer-or-name _requested-width)
;   (let ((window (split-window-below)))
;     (select-window window)
;     (evil-move-window 'below))
;   (set-window-buffer (selected-window) buffer-or-name))

; (setq difftastic-display-buffer-function #'my/difftastic-pop-at-bottom)

; (setq difftastic-requested-window-width-function
;       (lambda () (- (frame-width) 4)))

; (use-package forge
;   :after magit
;   :straight t
;   :config
;   (add-to-list 'forge-alist '("gitlab.etu.ru"
;                               "gitlab.etu.ru/api/v4"
;                               "gitlab.etu.ru"
;                               forge-gitlab-repository)))

; (defun my/password-store-get-field (entry field)
;   (if-let (field (password-store-get-field entry field))
;       field
;     (my/password-store-get-field entry field)))

; (defun my/ghub--token (host username package &optional nocreate forge)
;   (cond ((and (or (equal host "gitlab.etu.ru/api/v4")
;                   (equal host "gitlab.etu.ru/api"))
;               (equal username "pvkorytov"))
;          (my/password-store-get-field
;           "Job/Digital/Infrastructure/gitlab.etu.ru"
;           (format "%s-token" package)))
;         (t (error "Don't know token: %s %s %s" host username package))))

; (with-eval-after-load 'ghub
;   (advice-add #'ghub--token :override #'my/ghub--token))

; (use-package code-review
;   :straight (:host github :repo "phelrine/code-review" :branch "fix/closql-update")
;   :after forge
;   :config
;   (setq code-review-auth-login-marker 'forge)
;   (setq code-review-gitlab-base-url "gitlab.etu.ru")
;   (setq code-review-gitlab-host "gitlab.etu.ru/api")
;   (setq code-review-gitlab-graphql-host "gitlab.etu.ru/api")
;   (general-define-key
;    :states '(normal visual)
;    :keymaps '(code-review-mode-map)
;    "RET" #'code-review-comment-add-or-edit
;    "gr" #'code-review-reload
;    "r" #'code-review-transient-api
;    "s" #'code-review-comment-code-suggestion
;    "d" #'code-review-submit-single-diff-comment-at-point
;    "TAB" #'magit-section-toggle)
;   (general-define-key
;    :states '(normal)
;    :keymaps '(forge-topic-mode-map)
;    "M-RET" #'code-review-forge-pr-at-point))

; (defun my/code-review-comment-quit ()
;   "Quit the comment window."
;   (interactive)
;   (magit-mode-quit-window t)
;   (with-current-buffer (get-buffer code-review-buffer-name)
;     (goto-char code-review-comment-cursor-pos)
;     (code-review-comment-reset-global-vars)))

; (with-eval-after-load 'code-review
;   (advice-add #'code-review-comment-quit :override #'my/code-review-comment-quit))

(use-package editorconfig
  :straight t
  :config
  (add-to-list 'editorconfig-indentation-alist
               '(emmet-mode emmet-indentation))
  (editorconfig-mode))

(recentf-mode 1)

(save-place-mode nil)

(defun my/deadgrep-fix-buffer-advice (fun &rest args)
  (let ((buf (apply fun args)))
    (with-current-buffer buf
      (toggle-truncate-lines 1))
    buf))

(use-package deadgrep
  :straight t
  :commands (deadgrep)
  :config
  (advice-add #'deadgrep--buffer :around #'my/deadgrep-fix-buffer-advice))

; (defun my/register-clear (register)
;   (interactive (list (register-read-with-preview "Clear register: ")))
;   (setq register-alist (delq (assoc register register-alist) register-alist)))

; (setq register-preview-delay which-key-idle-delay)

; (my-leader-def
;   :infix "g"
;   "" '(:wk "registers & marks")
;   "y" #'copy-to-register
;   "p" #'insert-register
;   "o" #'point-to-register
;   "c" #'my/register-clear
;   "r" #'jump-to-register
;   "R" #'consult-register
;   "w" #'window-configuration-to-register)

; (defun my/push-mark-no-activate ()
;   "Pushes `point' to `mark-ring' and does not activate the region
;    Equivalent to \\[set-mark-command] when \\[transient-mark-mode] is disabled"
;   (interactive)
;   (push-mark (point) t nil)
;   (message "Pushed mark to ring"))

; (defun my/mark-ring-clear ()
;   (interactive)
;   (setq mark-ring nil))

; (my-leader-def
;   :infix "g"
;   "G" #'consult-global-mark
;   "g" #'consult-mark
;   "C" #'my/mark-ring-clear
;   "m" #'my/push-mark-no-activate)

; (general-define-key
;  :keymaps 'global
;  "C-SPC" #'my/push-mark-no-activate)

; (use-package avy
;   :straight t
;   :config
;   (setq avy-timeout-seconds 0.5)
;   (setq avy-ignored-modes
;         '(image-mode doc-view-mode pdf-view-mode exwm-mode))
;   (general-define-key
;    :states '(normal motion)
;    "-" #'avy-goto-char-timer))

; (defun avy-action-embark (pt)
;   (unwind-protect
;       (save-excursion
;         (goto-char pt)
;         (embark-act))
;     (select-window
;      (cdr (ring-ref avy-ring 0))))
;   t)

; (with-eval-after-load 'avy
;   (setf (alist-get ?. avy-dispatch-alist) 'avy-action-embark))

; (use-package ace-link
;   :straight t
;   :commands (ace-link-info ace-link-help ace-link-woman ace-link-eww))

; (use-package vertico
;   :straight t
;   :config
;   (setq enable-recursive-minibuffers t)
;   (general-define-key
;    :keymaps '(vertico-map)
;    "M-j" #'vertico-next
;    "M-k" #'vertico-previous
;    "TAB" #'minibuffer-complete)
;   (vertico-mode))

; (defun crm-indicator (args)
;   (cons (format "[CRM%s] %s"
;                 (replace-regexp-in-string
;                  "\\`\\[.*?]\\*\\|\\[.*?]\\*\\'" ""
;                  crm-separator)
;                 (car args))
;         (cdr args)))
; (with-eval-after-load 'crm
;   (advice-add #'completing-read-multiple :filter-args #'crm-indicator))

; (use-package savehist
;   :init
;   (savehist-mode))

; (use-package vertico-directory
;   :after (vertico)
;   :config
;   (general-define-key
;    :keymaps '(vertico-map)
;    "RET" #'vertico-directory-enter
;    "DEL" #'vertico-directory-delete-char)
;   (add-hook 'rfn-eshadow-update-overlay-hook #'vertico-directory-tidy))

; (use-package vertico-grid
;   :after (vertico))

; (defun my/sort-directories-first (files)
;   (setq files (vertico-sort-alpha files))
;   (nconc (seq-filter (lambda (x) (string-suffix-p "/" x)) files)
;          (seq-remove (lambda (x) (string-suffix-p "/" x)) files)))

; (use-package vertico-multiform
;   :after vertico
;   :config
;   (vertico-multiform-mode)
;   (general-define-key
;    :keymap 'vertico-multiform-map
;    "M-b" #'vertico-multiform-buffer
;    "M-g" #'vertico-multiform-grid)
;   (setq vertico-multiform-categories
;         '((file (vertico-sort-function . my/sort-directories-first))
;           (password-store-pass grid)))
;   (setq vertico-multiform-commands
;         '((eshell-atuin-history (vertico-sort-function . nil))
;           (my/index-nav (vertico-sort-function . nil))
;           (org-ql-view (vertico-sort-function . nil))
;           (my/consult-line (vertico-sort-function . nil))
;           (telega-msg-add-reaction grid))))

; (use-package vertico-quick
;   :after vertico
;   :config
;   (general-define-key
;    :keymaps '(vertico-map)
;    "M-q" #'vertico-quick-insert
;    "C-q" #'vertico-quick-exit))

; (use-package orderless
;   :straight t
;   :config
;   (setq completion-styles '(orderless basic))
;   (setq completion-category-defaults nil)
;   (setq completion-category-overrides
;         '((file (styles partial-completion))))
;   (setq orderless-matching-styles
;         '(orderless-literal orderless-initialism orderless-regexp)))

; (defun company-completion-styles (capf-fn &rest args)
;   (let ((completion-styles '(basic partial-completion)))
;     (apply capf-fn args)))

; (with-eval-after-load 'company
;   (advice-add 'company-capf :around #'company-completion-styles))

; (use-package consult
;   :straight t
;   :config
;   (setq consult-preview-excluded-files
;         `("\\`/[^/|:]+:"
;           ,(rx "html" eos))))

; (use-package marginalia
;   :straight t
;   :config
;   (marginalia-mode)
;   (push '(projectile-find-file . file)
;         marginalia-command-categories))

; (use-package embark
;   :straight t
;   :commands (embark-act embark-dwim embark-bindings)
;   :init
;   (general-define-key
;    "M-e" #'embark-act))

; (use-package embark-consult
;   :straight t
;   :after (embark)
;   :config
;   (add-hook 'embark-collect-mode #'consult-preview-at-point-mode))

; (defun embark-which-key-indicator ()
;   "An embark indicator that displays keymaps using which-key.
; The which-key help message will show the type and value of the
; current target followed by an ellipsis if there are further
; targets."
;   (lambda (&optional keymap targets prefix)
;     (if (null keymap)
;         (which-key--hide-popup-ignore-command)
;       (which-key--show-keymap
;        (if (eq (plist-get (car targets) :type) 'embark-become)
;            "Become"
;          (format "Act on %s '%s'%s"
;                  (plist-get (car targets) :type)
;                  (embark--truncate-target (plist-get (car targets) :target))
;                  (if (cdr targets) "…" "")))
;        (if prefix
;            (pcase (lookup-key keymap prefix 'accept-default)
;              ((and (pred keymapp) km) km)
;              (_ (key-binding prefix 'accept-default)))
;          keymap)
;        nil nil t (lambda (binding)
;                    (not (string-suffix-p "-argument" (cdr binding))))))))

; (defun embark-hide-which-key-indicator (fn &rest args)
;   "Hide the which-key indicator immediately when using the completing-read prompter."
;   (which-key--hide-popup-ignore-command)
;   (let ((embark-indicators
;          (remq #'embark-which-key-indicator embark-indicators)))
;     (apply fn args)))

; (with-eval-after-load 'embark
;   (advice-add #'embark-completing-read-prompter
;               :around #'embark-hide-which-key-indicator)
;   (setq embark-indicators (delq #'embark-mixed-indicator embark-indicators))
;   (push #'embark-which-key-indicator embark-indicators))

; (my-leader-def
;   :infix "f"
;   "" '(:which-key "various completions")'
;   "b" #'persp-switch-to-buffer*
;   "e" 'micromamba-activate
;   "f" 'project-find-file
;   "c" 'consult-yank-pop
;   "a" 'consult-ripgrep
;   "d" 'deadgrep)

; (general-define-key
;  :states '(insert normal)
;  "C-y" 'consult-yank-pop)

; (defun my/consult-line ()
;   (interactive)
;   (if current-prefix-arg
;       (call-interactively #'consult-line-multi)
;     (consult-line nil t)))

; ;; (my-leader-def "SPC SPC" 'ivy-resume)
; (my-leader-def "s" 'my/consult-line)

(use-package company
  :straight t
  :config
  (global-company-mode)
  (setq company-idle-delay 0.2)
  (setq company-dabbrev-downcase nil)
  (setq company-show-numbers t))

(general-imap "C-SPC" 'company-complete)

(use-package company-box
  :straight t
  :if (display-graphic-p)
  :after (company)
  :hook (company-mode . company-box-mode))

(use-package helpful
  :straight t
  :commands (helpful-callable
             helpful-variable
             helpful-key
             helpful-macro
             helpful-function
             helpful-command))

; (my-leader-def
;   "h" '(:keymap help-map :which-key "help"))

; (my-leader-def
;   :infix "h"
;   "" '(:which-key "help")
;   "h" '(:keymap help-map :which-key "help-map")
;   "f" 'helpful-function
;   "k" 'helpful-key
;   "v" 'helpful-variable
;   "o" 'helpful-symbol
;   "i" 'info)

; (general-define-key
;  :keymaps 'help-map
;  "f" 'helpful-function
;  "k" 'helpful-key
;  "v" 'helpful-variable
;  "o" 'helpful-symbol)

; (use-package wakatime-mode
;   :straight (:host github :repo "SqrtMinusOne/wakatime-mode")
;   :if (not (or my/remote-server))
;   :config
;   (setq wakatime-ignore-exit-codes '(0 1 102 112))
;   (advice-add 'wakatime-init :after
;               (lambda ()
;                 (setq wakatime-cli-path (or
;                                          (executable-find "wakatime-cli")
;                                          (expand-file-name "~/bin/wakatime-cli")))))
;   (when (file-exists-p "~/.wakatime.cfg")
;     (setq wakatime-api-key
;           (string-trim
;            (shell-command-to-string "awk '/api-key/{print $NF}' ~/.wakatime.cfg"))))
;   ;; (setq wakatime-cli-path (executable-find "wakatime"))
;   (global-wakatime-mode))

(use-package request
  :straight t
  :defer t)

; (use-package activity-watch-mode
;   :straight t
;   :if (not (or my/is-termux my/remote-server))
;   :config
;   (global-activity-watch-mode))

(unless my/is-termux
  (tool-bar-mode -1)
  (menu-bar-mode -1)
  (scroll-bar-mode -1))

(when my/is-termux
  (menu-bar-mode -1))

; (set-frame-parameter (selected-frame) 'alpha '(90 . 90))
; (add-to-list 'default-frame-alist '(alpha . (90 . 90)))

; (global-prettify-symbols-mode)

(setq use-dialog-box nil)

(setq inhibit-startup-screen t)

(setq visible-bell 0)

(defalias 'yes-or-no-p 'y-or-n-p)

(setq make-pointer-invisible t)

(show-paren-mode 1)

(global-hl-line-mode 1)

(global-display-line-numbers-mode 1)
(line-number-mode nil)
(setq display-line-numbers-type 'visual)
(column-number-mode)

(setq word-wrap 1)
(global-visual-line-mode 1)

(setq-default frame-title-format
              '(""
                "emacs"
                ;; (:eval
                ;;  (let ((project-name (projectile-project-name)))
                ;;    (if (not (string= "-" project-name))
                ;;        (format ":%s@%s" project-name (system-name))
                ;;      (format "@%s" (system-name)))))
                ))

(use-package olivetti
  :straight t
  :if (display-graphic-p)
  :commands (olivetti-mode)
  :config
  (setq-default olivetti-body-width 86))

(use-package keycast
  :straight t
  :init
  (define-minor-mode keycast-mode
    "Keycast mode"
    :global t
    (if keycast-mode
        (progn
          (add-to-list 'global-mode-string '("" keycast-mode-line " "))
          (add-hook 'pre-command-hook 'keycast--update t) )
      (remove-hook 'pre-command-hook 'keycast--update)
      (setq global-mode-string (delete '("" keycast-mode-line " ") global-mode-string))))
  :commands (keycast--update))

(use-package doom-themes
  :straight t
  ;; Not deferring becuase I want `doom-themes-visual-bell-config'
  :config
  (setq doom-themes-enable-bold t
        doom-themes-enable-italic t)
  ;; (if my/remote-server
  ;;     (load-theme 'doom-gruvbox t)
  ;;   (load-theme 'doom-palenight t))
  (doom-themes-visual-bell-config)
  (setq doom-themes-treemacs-theme "doom-colors")
  (doom-themes-treemacs-config))


(use-package theme-magic
  :straight t)

(use-package modus-themes
  :straight t)

(use-package ef-themes
  :straight t
  :config
  (setq ef-duo-light-palette-overrides
        '((constant green))))

(use-package ct
  :straight t)

(defun my/doom-p ()
  (seq-find (lambda (x) (string-match-p (rx bos "doom") (symbol-name x)))
            custom-enabled-themes))

(defun my/modus-p ()
  (seq-find (lambda (x) (string-match-p (rx bos "modus") (symbol-name x)))
            custom-enabled-themes))

(defun my/ef-p ()
  (seq-find (lambda (x) (string-match-p (rx bos "ef") (symbol-name x)))
            custom-enabled-themes))

(defun my/light-p ()
  (ct-light-p (my/color-value 'bg)))

(defun my/dark-p ()
  (not (my/light-p)))

(defconst my/theme-override
  '((doom-palenight
     (red . "#f07178"))))

(defvar my/alpha-for-light 7)

(defun my/doom-color (color)
  (when (doom-color 'bg)
    (let ((override (alist-get (my/doom-p) my/theme-override))
          (color-name (symbol-name color))
          (is-light (ct-light-p (doom-color 'bg))))
      (or
       (alist-get color override)
       (cond
        ((eq 'black color)
         (if is-light (doom-color 'fg) (doom-color 'bg)))
        ((eq 'white color)
         (if is-light (doom-color 'bg) (doom-color 'fg)))
        ((eq 'border color)
         (if is-light (doom-color 'base0) (doom-color 'base8)))
        ((string-match-p (rx bos "light-") color-name)
         (ct-edit-hsl-l-inc (my/doom-color (intern (substring color-name 6)))
                            my/alpha-for-light))
        ((string-match-p (rx bos "dark-") color-name)
         (or (doom-color color)
             (ct-edit-hsl-l-dec (my/doom-color (intern (substring color-name 5)))
                                my/alpha-for-light)))
        (t (doom-color color)))))))

(defun my/modus-get-base (color)
  (let ((base-value (string-to-number (substring (symbol-name color) 4 5)))
        (base-start (cadr (assoc 'bg-main (modus-themes--current-theme-palette))))
        (base-end (cadr (assoc 'fg-dim (modus-themes--current-theme-palette)))))
    (nth base-value (ct-gradient 9 base-start base-end t))))

(defun my/prot-color (color palette)
  (let ((is-light (ct-light-p (cadr (assoc 'bg-main palette)))))
    (cond
     ((member color '(black white light-black light-white))
      (let ((bg-main (cadr (assoc 'bg-main palette)))
            (fg-main (cadr (assoc 'fg-main palette))))
        (pcase color
          ('black (if is-light fg-main bg-main))
          ('white (if is-light bg-main fg-main))
          ('light-black (ct-edit-hsl-l-inc
                         (if is-light fg-main bg-main)
                         15))
          ('light-white (ct-edit-hsl-l-inc
                         (if is-light bg-main fg-main)
                         15)))))
     ((or (eq color 'bg))
      (cadr (assoc 'bg-main palette)))
     ((or (eq color 'fg))
      (cadr (assoc 'fg-main palette)))
     ((eq color 'bg-alt)
      (cadr (assoc 'bg-dim palette)))
     ((eq color 'violet)
      (cadr (assoc 'magenta-cooler palette)))
     ((string-match-p (rx bos "base" digit) (symbol-name color))
      (my/modus-get-base color))
     ((string-match-p (rx bos "dark-") (symbol-name color))
      (cadr (assoc (intern (format "%s-cooler" (substring (symbol-name color) 5)))
                   palette)))
     ((eq color 'grey)
      (my/modus-get-base 'base5))
     ((string-match-p (rx bos "light-") (symbol-name color))
      (or
       (cadr (assoc (intern (format "%s-intense" (substring (symbol-name color) 6))) palette))
       (cadr (assoc (intern (format "bg-%s-intense" (substring (symbol-name color) 6))) palette))))
     (t (cadr (assoc color palette))))))

(defun my/modus-color (color)
  (my/prot-color color (modus-themes--current-theme-palette)))

(defun my/ef-color (color)
  (my/prot-color color (ef-themes--current-theme-palette)))

(defconst my/test-colors-list
  '(black red green yellow blue magenta cyan white light-black
          dark-red dark-green dark-yellow dark-blue dark-magenta dark-cyan
          light-red light-green light-yellow light-blue light-magenta
          light-cyan light-white bg bg-alt fg fg-alt violet grey base0 base1
          base2 base3 base4 base5 base6 base7 base8 border))

(defun my/test-colors ()
  (interactive)
  (let ((buf (generate-new-buffer "*colors-test*")))
    (with-current-buffer buf
      (insert (format "%-20s %-10s %-10s %-10s" "Color" "Doom" "Modus" "Ef") "\n")
      (cl-loop for color in my/test-colors-list
               do (insert
                   (format "%-20s %-10s %-10s %-10s\n"
                           (prin1-to-string color)
                           (my/doom-color color)
                           (my/modus-color color)
                           (my/ef-color color))))
      (special-mode)
      (rainbow-mode))
    (switch-to-buffer buf)))

(defun my/color-value (color)
  (cond
   ((stringp color) (my/color-value (intern color)))
   ((eq color 'bg-other)
    (or (my/color-value 'bg-dim)
        (let ((color (my/color-value 'bg)))
          (if (ct-light-p color)
              (ct-edit-hsl-l-dec color 2)
            (ct-edit-hsl-l-dec color 3)))))
   ((eq color 'modeline)
    (or
     (my/color-value 'bg-mode-line-active)
     (my/color-value 'bg-mode-line)
     (if (my/light-p)
         (ct-edit-hsl-l-dec (my/color-value 'bg-alt) 10)
       (ct-edit-hsl-l-inc (my/color-value 'bg-alt) 15))))
   ((my/doom-p) (my/doom-color color))
   ((my/modus-p) (my/modus-color color))
   ((my/ef-p) (my/ef-color color))))

(deftheme my-theme-1)

(defvar my/my-theme-update-color-params nil)

(defmacro my/use-colors (&rest data)
  `(progn
     ,@(cl-loop for i in data collect
                `(setf (alist-get ',(car i) my/my-theme-update-color-params)
                       (list ,@(cl-loop for (key value) on (cdr i) by #'cddr
                                        append `(,key ',value)))))
     (when (and (or (my/doom-p) (my/modus-p)) my/emacs-started)
       (my/update-my-theme))))

(defun my/update-my-theme (&rest _)
  (interactive)
  (cl-loop for (face . values) in my/my-theme-update-color-params
           do (custom-theme-set-faces
               'my-theme-1
               `(,face ((t ,@(cl-loop for (key value) on values by #'cddr
                                      collect key
                                      collect (eval value)))))))
  (enable-theme 'my-theme-1))

(unless my/is-termux
  (advice-add 'load-theme :after #'my/update-my-theme)
  (add-hook 'emacs-startup-hook #'my/update-my-theme))

(my/use-colors
 (tab-bar-tab :background (my/color-value 'bg)
              :foreground (my/color-value 'yellow)
              :underline (my/color-value 'yellow))
 (tab-bar :background 'unspecified :foreground 'unspecified)
 (magit-section-secondary-heading :foreground (my/color-value 'blue)
                                  :weight 'bold))

(defun my/switch-theme (theme)
  (interactive
   (list (intern (completing-read "Load custom theme: "
                                  (mapcar #'symbol-name
                                          (custom-available-themes))))))
  (cl-loop for enabled-theme in custom-enabled-themes
           if (not (or (eq enabled-theme 'my-theme-1)
                       (eq enabled-theme theme)))
           do (disable-theme enabled-theme))
  (load-theme theme t)
  (when current-prefix-arg
    (my/regenerate-desktop)))

(if my/is-termux
    (progn
      (my/switch-theme 'modus-operandi-tinted))
  (my/switch-theme 'ef-duo-light))

(with-eval-after-load 'transient
  (my/use-colors
   (transient-key-exit :foreground (my/color-value 'dark-red))
   (transient-key-noop :foreground (my/color-value 'grey))
   (transient-key-return :foreground (my/color-value 'yellow))
   (transient-key-stay :foreground (my/color-value 'green))))

(use-package auto-dim-other-buffers
  :straight t
  :if (display-graphic-p)
  :config
  (auto-dim-other-buffers-mode t)
  (my/use-colors
   (auto-dim-other-buffers-face
    :background (my/color-value 'bg-other))))

(with-eval-after-load 'ansi-color
  (my/use-colors
   (ansi-color-black
    :foreground (my/color-value 'base2) :background (my/color-value 'base0))
   (ansi-color-red
    :foreground (my/color-value 'red) :background (my/color-value 'red))
   (ansi-color-green
    :foreground (my/color-value 'green) :background (my/color-value 'green))
   (ansi-color-yellow
    :foreground (my/color-value 'yellow) :background (my/color-value 'yellow))
   (ansi-color-blue
    :foreground (my/color-value 'dark-blue) :background (my/color-value 'dark-blue))
   (ansi-color-magenta
    :foreground (my/color-value 'violet) :background (my/color-value 'violet))
   (ansi-color-cyan
    :foreground (my/color-value 'dark-cyan) :background (my/color-value 'dark-cyan))
   (ansi-color-white
    :foreground (my/color-value 'base8) :background (my/color-value 'base8))
   (ansi-color-bright-black
    :foreground (my/color-value 'base5) :background (my/color-value 'base5))
   (ansi-color-bright-red
    :foreground (my/color-value 'orange) :background (my/color-value 'orange))
   (ansi-color-bright-green
    :foreground (my/color-value 'teal) :background (my/color-value 'teal))
   (ansi-color-bright-yellow
    :foreground (my/color-value 'yellow) :background (my/color-value 'yellow))
   (ansi-color-bright-blue
    :foreground (my/color-value 'blue) :background (my/color-value 'blue))
   (ansi-color-bright-magenta
    :foreground (my/color-value 'magenta) :background (my/color-value 'magenta))
   (ansi-color-bright-cyan
    :foreground (my/color-value 'cyan) :background (my/color-value 'cyan))
   (ansi-color-bright-white
    :foreground (my/color-value 'fg) :background (my/color-value 'fg))))

(when (display-graphic-p)
  (if (x-list-fonts "JetBrainsMono Nerd Font")
      (let ((font "-JB  -JetBrainsMono Nerd Font-medium-normal-normal-*-17-*-*-*-m-0-iso10646-1"))
        (set-frame-font font nil t)
        (add-to-list 'default-frame-alist `(font . ,font)))
    (message "Install JetBrainsMono Nerd Font!")))

(when (display-graphic-p)
  (set-face-attribute 'variable-pitch nil :family "Cantarell" :height 1.0)
  (set-face-attribute
   'italic nil
   :family "JetBrainsMono Nerd Font"
   :weight 'regular
   :slant 'italic))

(use-package ligature
  :straight (:host github :repo "mickeynp/ligature.el")
  :if (display-graphic-p)
  :config
  (ligature-set-ligatures
   '(
     typescript-mode
     typescript-ts-mode
     js2-mode
     javascript-ts-mode
     vue-mode
     svelte-mode
     scss-mode
     php-mode
     python-mode
     python-ts-mode
     js-mode
     markdown-mode
     clojure-mode
     go-mode
     sh-mode
     haskell-mode
     web-mode)
   '("--" "---" "==" "===" "!=" "!==" "=!=" "=:=" "=/=" "<="
     ">=" "&&" "&&&" "&=" "++" "+++" "***" ";;" "!!" "??"
     "?:" "?." "?=" "<:" ":<" ":>" ">:" "<>" "<<<" ">>>"
     "<<" ">>" "||" "-|" "_|_" "|-" "||-" "|=" "||=" "##"
     "###" "####" "#{" "#[" "]#" "#(" "#?" "#_" "#_(" "#:"
     "#!" "#=" "^=" "<$>" "<$" "$>" "<+>" "<+" "+>" "<*>"
     "<*" "*>" "</" "</>" "/>" "<!--" "<#--" "-->" "->" "->>"
     "<<-" "<-" "<=<" "=<<" "<<=" "<==" "<=>" "<==>" "==>" "=>"
     "=>>" ">=>" ">>=" ">>-" ">-" ">--" "-<" "-<<" ">->" "<-<"
     "<-|" "<=|" "|=>" "|->" "<->" "<~~" "<~" "<~>" "~~" "~~>"
     "~>" "~-" "-~" "~@" "[||]" "|]" "[|" "|}" "{|" "[<"
     ">]" "|>" "<|" "||>" "<||" "|||>" "<|||" "<|>" "..." ".."
     ".=" ".-" "..<" ".?" "::" ":::" ":=" "::=" ":?" ":?>"
     "//" "///" "/*" "*/" "/=" "//=" "/==" "@_" "__"))
  (global-ligature-mode t))

(use-package nerd-icons
  :straight t)

(use-package indent-bars
  :straight (:host github :repo "jdtsmith/indent-bars")
  :if (not (or my/remote-server))
  :hook ((prog-mode . indent-bars-mode)
         (LaTeX-mode . indent-bars-mode))
  :config
  (require 'indent-bars-ts)
  (setopt indent-bars-no-descend-lists t
          indent-bars-treesit-support t
          indent-bars-width-frac 0.3))

(use-package rainbow-delimiters
  :straight t
  :hook ((prog-mode . rainbow-delimiters-mode)))

(use-package rainbow-mode
  :commands (rainbow-mode)
  :straight t)

(use-package hl-todo
  :hook (prog-mode . hl-todo-mode)
  :straight t)

(use-package doom-modeline
  :straight t
  ;; :if (not (display-graphic-p))
  :init
  (setq doom-modeline-env-enable-python nil)
  (setq doom-modeline-env-enable-go nil)
  (setq doom-modeline-buffer-encoding 'nondefault)
  (setq doom-modeline-hud t)
  (setq doom-modeline-persp-icon nil)
  (setq doom-modeline-persp-name nil)
  (setq doom-modeline-display-misc-in-all-mode-lines nil)
  (when my/is-termux
    (setopt doom-modeline-icon nil))
  :config
  (setq doom-modeline-minor-modes nil)
  (setq doom-modeline-irc nil)
  (setq doom-modeline-buffer-state-icon nil)
  (doom-modeline-mode 1))

(defun my/tab-bar-mode-line--format ()
  (unless (derived-mode-p 'company-box-mode)
    (cl-letf (((symbol-function 'window-pixel-width)
               'frame-pixel-width)
              ((symbol-function 'window-margins)
               (lambda (&rest _)
                 (list nil))))
      (let ((doom-modeline-window-width-limit nil)
            (doom-modeline--limited-width-p nil))
        (format-mode-line
         '("%e"
           (:eval
            (doom-modeline-format--main))))))))

(defun my/hide-mode-line-if-only-window ()
  (let* ((windows (window-list))
         (hide-mode-line-p (length= windows 1)))
    (dolist (win windows)
      (with-current-buffer (window-buffer win)
        (unless (eq hide-mode-line-p hide-mode-line-mode)
          (hide-mode-line-mode
           (if hide-mode-line-p +1 -1)))))))

(define-minor-mode my/tab-bar-mode-line-mode
  "Use tab-bar as mode line mode."
  :global t
  (if my/tab-bar-mode-line-mode
      (progn
        (tab-bar-mode +1)
        (setq tab-bar-format '(my/tab-bar-mode-line--format))
        (set-face-attribute 'tab-bar nil :inherit 'mode-line)
        (add-hook 'window-configuration-change-hook #'my/hide-mode-line-if-only-window)

        (dolist (buf (buffer-list))
          (with-current-buffer buf
            (doom-modeline-set-modeline 'minimal)))
        (doom-modeline-set-modeline 'minimal 'default)

        (dolist (frame (frame-list))
          (with-selected-frame frame
            (my/hide-mode-line-if-only-window))
          (when-let (cb-frame (company-box--get-frame frame))
            (set-frame-parameter cb-frame 'tab-bar-lines 0)))
        (setenv "POLYBAR_BOTTOM" "false")
        (when (fboundp #'my/exwm-run-polybar)
          (my/exwm-run-polybar)))
    (tab-bar-mode -1)
    (setq tab-bar-format
          '(tab-bar-format-history tab-bar-format-tabs tab-bar-separator tab-bar-format-add-tab))
    (set-face-attribute 'tab-bar nil :inherit 'default)
    (remove-hook 'window-configuration-change-hook #'my/hide-mode-line-if-only-window)
    (global-hide-mode-line-mode -1)
    (dolist (buf (buffer-list))
      (with-current-buffer buf
        (doom-modeline-set-modeline 'main)))
    (doom-modeline-set-modeline 'main 'default)
    (setenv "POLYBAR_BOTTOM" "true")
    (when (fboundp #'my/exwm-run-polybar)
      (my/exwm-run-polybar))))

; (use-package perspective
;   :straight t
;   :init
;   ;; (setq persp-show-modestring 'header)
;   (setq persp-sort 'created)
;   (setq persp-suppress-no-prefix-key-warning t)
;   :config
;   (persp-mode)
;   ;;(my-leader-def "x" '(:keymap perspective-map :which-key "perspective"))
;   (general-define-key
;    :keymaps 'override
;    :states '(normal emacs)
;    "gt" 'persp-next
;    "gT" 'persp-prev
;    "gn" 'persp-switch
;    "gN" 'persp-kill)
;   (general-define-key
;    :keymaps 'perspective-map
;    "b" 'persp-switch-to-buffer
;    "x" 'persp-switch-to-buffer*
;    "u" 'persp-ibuffer))

(defun my/persp-move-window-and-switch ()
  (interactive)
  (let* ((buffer (current-buffer)))
    (call-interactively #'persp-switch)
    (persp-set-buffer (buffer-name buffer))
    (switch-to-buffer buffer)))

(defun my/persp-copy-window-and-switch ()
  (interactive)
  (let* ((buffer (current-buffer)))
    (call-interactively #'persp-switch)
    (persp-add-buffer (buffer-name buffer))
    (switch-to-buffer buffer)))

(with-eval-after-load 'perspective
  (general-define-key
   :keymaps 'perspective-map
   "m" #'my/persp-move-window-and-switch
   "f" #'my/persp-copy-window-and-switch))

(setq my/perspective-assign-alist '())

(defvar my/perspective-assign-ignore nil
  "If non-nil, ignore `my/perspective-assign'")

(defun my/perspective-assign ()
  (when-let* ((_ (not my/perspective-assign-ignore))
              (rule (alist-get major-mode my/perspective-assign-alist)))
    (let ((workspace-index (car rule))
          (persp-name (cadr rule))
          (buffer (current-buffer)))
      (if (fboundp #'perspective-exwm-assign-window)
          (progn
            (perspective-exwm-assign-window
             :workspace-index workspace-index
             :persp-name persp-name)
            (when workspace-index
              (exwm-workspace-switch workspace-index))
            (when persp-name
              (persp-switch persp-name)))
        (with-perspective persp-name
          (persp-set-buffer buffer))
        (persp-switch-to-buffer buffer)))))

(defun my/perspective-assign-ignore-advice (fun &rest args)
  (let ((my/perspective-assign-ignore t))
    (apply fun args)))

(add-hook 'after-change-major-mode-hook #'my/perspective-assign)

(defmacro my/persp-add-rule (&rest body)
  (declare (indent 0))
  (unless (= (% (length body) 3) 0)
    (error "Malformed body in my/persp-add-rule"))
  (let (result)
    (while body
      (let ((major-mode (pop body))
            (workspace-index (pop body))
            (persp-name (pop body)))
        (push
         `(add-to-list 'my/perspective-assign-alist
                       '(,major-mode . (,workspace-index ,persp-name)))
         result)))
    `(progn
       ,@result)))

(defmacro my/command-in-persp (command-name persp-name workspace-index &rest args)
  `'((lambda ()
       (interactive)
       (when (and ,workspace-index (fboundp #'exwm-workspace-switch-create))
         (exwm-workspace-switch-create ,workspace-index))
       (persp-switch ,persp-name)
       (delete-other-windows)
       ,@args)
     :wk ,command-name))


(use-package dashboard
  :straight t
  :ensure t
  :init
  (progn
   ; (setq recentf-exclude '("/Users/gmarx/beorg/"))
    (setq dashboard-items '(
          (recents . 5)
          ;(bookmarks . 5)
          ;(projects . 5)
          (agenda . 5)))
    (setq dashboard-banner-logo-title "Welcome Fabio Lima")
    (setq dashboard-set-file-icons t)
    (setq dashboard-set-init-info t)
    (setq dashboard-startup-banner 'logo)
    (setq dashboard-center-content t)
    (setq dashboard-insert-footer t)
    )
  :config
  (dashboard-setup-startup-hook))


(use-package centaur-tabs
  :straight t
  :demand
  :config
  ;(centaur-tabs-mode t)
  
  (setq centaur-tabs-set-icons t)
  (setq x-underline-at-descent-line t)
  :hook
  (dired-mode . centaur-tabs-local-mode)
  )


(use-package treemacs
  :straight t
  :ensure t
  :init
  (with-eval-after-load 'winum
    (define-key winum-keymap (kbd "M-0") #'treemacs-select-window))
  :config
  (progn
    (setq treemacs-is-never-other-window t)
    (setq treemacs-width 35)
    )
  :bind
  (:map global-map
        ("M-0"       . treemacs-select-window)
  ("C-x t t"   . treemacs)))


(use-package treemacs-evil
  :after (treemacs evil)
  :straight t)

(use-package lsp-mode
  :straight t
  :if (not (or my/is-termux my/remote-server))
  :hook (
         (typescript-mode . lsp)
         (js-mode . lsp)
         (vue-mode . lsp)
         (go-mode . lsp)
         (svelte-mode . lsp)
         ;; (python-mode . lsp)
         (json-mode . lsp)
         (haskell-mode . lsp)
         (haskell-literate-mode . lsp)
         (java-mode . lsp)
         ;; (csharp-mode . lsp)
         )
  :commands lsp
  :init
  (setq lsp-keymap-prefix nil)
  :config
  (setq lsp-idle-delay 1)
  (setq lsp-eslint-server-command '("node" "/home/pavel/.emacs.d/.cache/lsp/eslint/unzipped/extension/server/out/eslintServer.js" "--stdio"))
  (setq lsp-eslint-run "onSave")
  (setq lsp-signature-render-documentation nil)
  ;; (lsp-headerline-breadcrumb-mode nil)
  (setq lsp-headerline-breadcrumb-enable nil)
  (setq lsp-modeline-code-actions-enable nil)
  (setq lsp-modeline-diagnostics-enable nil)
  (add-to-list 'lsp-language-id-configuration '(svelte-mode . "svelte")))

(use-package lsp-ui
  :straight t
  :commands lsp-ui-mode
  :config
  (setq lsp-ui-doc-delay 2)
  (setq lsp-ui-sideline-show-hover nil))

(use-package all-the-icons
  :straight t)

;
(use-package major-mode-hydra
  :straight t
  :ensure t
  :bind
  ("M-SPC" . major-mode-hydra))



(use-package hydra
  :straight t
  :config
  :ensure t
  ;(global-set-key (kbd "<f8>") 'hydra-major/body)
  ;(global-set-key (kbd "<f3>")   'hydra-bib-etc/body)
  ;(global-set-key (kbd "C-<f3>") 'hydra-dired/body)
)






(defhydra hydra-major (:color blue :columns 5)
  "Latex"
  ("a" org-beamer-export-to-pdf "Beamer PDF")
  ("s" org-beamer-export-to-latex "Beamer")
  ("d" org-latex-export-to-latex  "Latex")
  ("f" org-latex-export-to-pdf "Latex PDF")
  ("h" org-html-export-to-html "HTML"))

(global-set-key (kbd "C-c c") 'hydra-major/body)



(use-package major-mode-hydra
  :straight (:host github :repo "jerrypnz/major-mode-hydra.el")
  :ensure t
  :bind
  ("M-SPC" . major-mode-hydra))

(major-mode-hydra-define emacs-lisp-mode nil
  ("TEX"
   (("b" eval-buffer "buffer")
    ("e" eval-defun "defun")
    ("r" eval-region "region"))
   "REPL"
   (("I" ielm "ielm"))
   "Python"
   (("t" ert "prompt")
    ("T" (ert t) "all")
    ("F" (ert :failed) "failed"))
   "Doc"
   (("d" describe-foo-at-point "thing-at-pt")
    ("f" describe-function "function")
    ("v" describe-variable "variable")
    ("i" info-lookup-symbol "info lookup"))))

(global-set-key (kbd "C-c b") 'emacs-lisp-mode )

 





(use-package ob-latex                                      ;
  ;;  :straight t
  :ensure nil
  :after org
  :defer
  :custom (org-latex-compiler "lualatex"))




(unless (boundp 'org-latex-classes)
  (setq org-latex-classes nil))


(setq org-beamer-outline-frame-title "Sumário")


(with-eval-after-load "ox-latex"


  (add-to-list 'org-latex-classes
               '("beamer"
                 "\\documentclass{beamer}
                [PACKAGES]
                [NO-DEFAULT-PACKAGES]"
                 ("\\section{%s}" . "\\section*{%s}")
                 ("\\subsection{%s}" . "\\subsection*{%s}")
                 ("\\subsubsection{%s}" . "\\subsubsection*{%s}")
                 ("\\paragraph{%s}" . "\\paragraph*{%s}")
                 ("\\subparagraph{%s}" . "\\subparagraph*{%s}")))
  )



(add-to-list 'org-latex-classes
             '("koma-article" "\\documentclass{scrartcl}
                            [NO-DEFAULT-PACKAGES]"
               ("\\section{%s}" . "\\section*{%s}")
               ("\\subsection{%s}" . "\\subsection*{%s}")
               ("\\subsubsection{%s}" . "\\subsubsection*{%s}")
               ("\\paragraph{%s}" . "\\paragraph*{%s}")
               ("\\subparagraph{%s}" . "\\subparagraph*{%s}")))

;;
;; Custom classes
;;;
(add-to-list 'org-latex-classes
             '("koma-book" "\\documentclass{scrbook}
                    [NO-DEFAULT-PACKAGES]"
               ("\\section{%s}" . "\\section*{%s}")
               ("\\subsection{%s}" . "\\subsection*{%s}")
               ("\\subsubsection{%s}" . "\\subsubsection*{%s}")
               ("\\paragraph{%s}" . "\\paragraph*{%s}")
               ("\\subparagraph{%s}" . "\\subparagraph*{%s}")))



(add-to-list 'org-latex-classes
             '("memoir-article"
               "\\documentclass[12pt,oneside,article]{memoir}
                [PACKAGES]
                [NO-DEFAULT-PACKAGES]"
               ("\\section{%s}" . "\\section*{%s}")
               ("\\subsection{%s}" . "\\subsection*{%s}")
               ("\\subsubsection{%s}" . "\\subsubsection*{%s}")
               ("\\paragraph{%s}" . "\\paragraph*{%s}")
               ("\\subparagraph{%s}" . "\\subparagraph*{%s}")))


;;;; Custom  title beamer


(setq org-latex-title-command
      "\\begingroup
  \\setbeamertemplate{headline}{}
  \\maketitle
  \\endgroup")




(use-package markdown-mode
  :straight t
  :mode "\\.md\\'"
  :config
  (setq markdown-command
        (concat
         "pandoc"
         " --from=markdown --to=html"
         " --standalone --mathjax --highlight-style=pygments"
         " --css=pandoc.css"
         " --quiet"
         ))
  (setq markdown-live-preview-delete-export 'delete-on-export)
  (setq markdown-asymmetric-header t)
  ;(setq markdown-open-command "/home/pavel/bin/scripts/chromium-sep")
  ;(add-hook 'markdown-mode-hook #'smartparens-mode)
  (general-define-key
   :keymaps 'markdown-mode-map
   "M-<left>" 'markdown-promote
   "M-<right>" 'markdown-demote))


(use-package csv-mode
  :straight t
  :disabled
  :mode "\\.csv\\'")


(use-package gnuplot
  :straight t
  :commands (gnuplot-mode gnuplot-make-buffer)
  :init
  (add-to-list 'auto-mode-alist '("\\.gp\\'" . gnuplot-mode))
  :config
  (general-define-key
   :keymaps 'gnuplot-mode-map
   "C-c C-c" #'gnuplot-send-buffer-to-gnuplot)
  (general-define-key
   :states '(normal)
   :keymaps 'gnuplot-mode-map
   "RET" #'gnuplot-send-buffer-to-gnuplot)
  (add-hook 'gnuplot-mode-hook #'smartparens-mode))


(use-package haskell-mode
  :straight t
  :mode "\\.hs\\'")

(use-package lsp-haskell
  :straight t
  :after (lsp haskell-mode))


(use-package lua-mode
  :straight t
  :mode "\\.lua\\'"
  :hook (lua-mode . smartparens-mode))

; (my/set-smartparens-indent 'lua-mode)

  (setq org-directory (expand-file-name "~/30-39 Life/32 org-mode"))

(use-package org
  :straight (:type built-in)
  ; :if (not my/remote-server)
  :defer t
  :init
  (unless (file-exists-p org-directory)
    (mkdir org-directory t))
  :config
  ; (setq org-startup-indented (not my/is-termux))
  (setq org-return-follows-link t)
  (setq org-src-tab-acts-natively nil)
  ; (add-hook 'org-mode-hook 'smartparens-mode)
  (add-hook 'org-agenda-mode-hook
            (lambda ()
              (visual-line-mode -1)
              (toggle-truncate-lines 1)
              (display-line-numbers-mode 0)))
  (add-hook 'org-mode-hook
            (lambda ()
              (rainbow-delimiters-mode -1))))





(use-package org-bullets
  ;:after org
  :straight t
  :hook (org-mode . org-bullets-mode)
  :custom
  (org-bullets-bullet-list '("◉" "○" "●" "○" "●" "○" "●")))




; (use-package org-super-agenda
;   :straight t
;   :after org-agenda
;   :custom (org-super-agenda-groups
;            '( ;; Each group has an implicit boolean OR operator between its selectors.
;              (:name "Overdue" :deadline past :order 0)
;              (:name "Evening Habits" :and (:habit t :tag "evening") :order 8)
;              (:name "Habits" :habit t :order 6)
;              (:name "Today" ;; Optionally specify section name
;               :time-grid t  ;; Items that appear on the time grid (scheduled/deadline with time)
;               :order 3)     ;; capture the today first but show it in order 3
;              (:name "Low Priority" :priority "C" :tag "maybe" :order 7)
;              (:name "Due Today" :deadline today :order 1)
;              (:name "Important"
;               :and (:priority "A" :not (:todo ("DONE" "CANCELED")))
;               :order 2)
;              (:name "Due Soon" :deadline future :order 4)
;              (:name "Todo" :not (:habit t) :order 5)
;              (:name "Waiting" :todo ("WAITING" "HOLD") :order 9)))
;   :config
;   (setq org-super-agenda-header-map nil)
;   (org-super-agenda-mode t))


(when (display-graphic-p)
 (use-package pdf-view
    :ensure pdf-tools
    :diminish (pdf-view-themed-minor-mode
               pdf-view-midnight-minor-mode
               pdf-view-printer-minor-mode)
    :defines pdf-annot-activate-created-annotations
    :hook ((pdf-tools-enabled . pdf-view-auto-slice-minor-mode)
           (pdf-tools-enabled . pdf-isearch-minor-mode))
    :mode ("\\.[pP][dD][fF]\\'" . pdf-view-mode)
    :magic ("%PDF" . pdf-view-mode)
    :bind (:map pdf-view-mode-map
           ("C-s" . isearch-forward))
    :init (setq pdf-view-use-scaling t
                pdf-view-use-imagemagick nil
                pdf-annot-activate-created-annotations t)
    :config
    ;; Activate the package
    (pdf-tools-install t nil t nil)

    ;; Recover last viewed position
    (use-package saveplace-pdf-view
      :when (ignore-errors (pdf-info-check-epdfinfo) t)
      :autoload (saveplace-pdf-view-find-file-advice saveplace-pdf-view-to-alist-advice)
      :init
      (advice-add 'save-place-find-file-hook :around #'saveplace-pdf-view-find-file-advice)
      (advice-add 'save-place-to-alist :around #'saveplace-pdf-view-to-alist-advice))))



(use-package hide-mode-line
  :straight t
  :commands (hide-mode-line-mode))

; (defun my/present-next-with-latex ()
;   (interactive)
;   (org-present-next)
;   (org-latex-preview '(16)))

; (defun my/present-prev-with-latex ()
;   (interactive)
;   (org-present-prev)
;   (org-latex-preview '(16)))

; (use-package org-present
;   :straight (:host github :repo "rlister/org-present")
;   :if (not my/remote-server)
;   :commands (org-present)
;   :config
;   (general-define-key
;    :keymaps 'org-present-mode-keymap
;    "<next>" 'my/present-next-with-latex
;    "<prior>" 'my/present-prev-with-latex)
;   (setq org-present-mode-hook
;         (list (lambda ()
;                 (blink-cursor-mode 0)
;                 (org-present-big)
;                 (org-bars-mode -1)
;                 ;; (org-display-inline-images)
;                 (org-present-hide-cursor)
;                 (org-present-read-only)
;                 (display-line-numbers-mode 0)
;                 (hide-mode-line-mode +1)
;                 (setq-local org-format-latex-options
;                             (plist-put org-format-latex-options
;                                        :scale (* org-present-text-scale my/org-latex-scale 0.5)))
;                 ;; (org-latex-preview '(16))
;                 ;; TODO ^somehow this stucks at running LaTeX^
;                 (setq-local olivetti-body-width 60)
;                 (olivetti-mode 1))))
;   (setq org-present-mode-quit-hook
;         (list (lambda ()
;                 (blink-cursor-mode 1)
;                 (org-present-small)
;                 (org-bars-mode 1)
;                 ;; (org-remove-inline-images)
;                 (org-present-show-cursor)
;                 (org-present-read-write)
;                 (display-line-numbers-mode 1)
;                 (hide-mode-line-mode 0)
;                 (setq-local org-format-latex-options (plist-put org-format-latex-options :scale my/org-latex-scale))
;                 (org-latex-preview '(64))
;                 (olivetti-mode -1)
;                 (setq-local olivetti-body-width (default-value 'olivetti-body-width))))))



  ;; Table of contents
  (use-package toc-org
    :straight t
    :hook (org-mode . toc-org-mode))

  ;; Export text/html MIME emails
  (use-package org-mime
    :straight t
    :bind (:map message-mode-map
           ("C-c M-o" . org-mime-htmlize)
           :map org-mode-map
           ("C-c M-o" . org-mime-org-buffer-htmlize)))

  ;; Auto-toggle Org LaTeX fragments
  (use-package org-fragtog
    :straight t
    :diminish
    :hook (org-mode . org-fragtog-mode))

  ;; Preview
  (use-package org-preview-html
    :straight t
    :diminish
    :bind (:map org-mode-map
           ("C-c C-h" . org-preview-html-mode))
    :init (when (and (featurep 'xwidget-internal) (display-graphic-p))
            (setq org-preview-html-viewer 'xwidget)))

  ;; Presentation
  (use-package org-tree-slide
    :straight t
    :diminish
    :functions (org-display-inline-images
                org-remove-inline-images)
    :bind (:map org-mode-map
           ("s-<f7>" . org-tree-slide-mode)
           :map org-tree-slide-mode-map
           ("<left>" . org-tree-slide-move-previous-tree)
           ("<right>" . org-tree-slide-move-next-tree)
           ("S-SPC" . org-tree-slide-move-previous-tree)
           ("SPC" . org-tree-slide-move-next-tree))
    :hook ((org-tree-slide-play . (lambda ()
                                    (text-scale-increase 4)
                                    (org-display-inline-images)
                                    (read-only-mode 1)))
           (org-tree-slide-stop . (lambda ()
                                    (text-scale-increase 0)
                                    (org-remove-inline-images)
                                    (read-only-mode -1))))
    :init (setq org-tree-slide-header nil
                org-tree-slide-slide-in-effect t
                org-tree-slide-heading-emphasis nil
                org-tree-slide-cursor-init t
                org-tree-slide-modeline-display 'outside
                org-tree-slide-skip-done nil
                org-tree-slide-skip-comments t
                org-tree-slide-skip-outline-level 3))

  ;; Pomodoro
  (use-package org-pomodoro
    :straight t
    :custom-face
    (org-pomodoro-mode-line ((t (:inherit warning))))
    (org-pomodoro-mode-line-overtime ((t (:inherit error))))
    (org-pomodoro-mode-line-break ((t (:inherit success))))
    :bind (:map org-mode-map
           ("C-c C-x m" . org-pomodoro))
    :init
    (with-eval-after-load 'org-agenda
      (bind-keys :map org-agenda-mode-map
        ("K" . org-pomodoro)
        ("C-c C-x m" . org-pomodoro))))

;; 


(use-package snow
  :straight (:repo "alphapapa/snow.el" :host github)
  :commands (snow))

(use-package power-mode
  :straight (:host github :repo "elizagamedev/power-mode.el")
  :disabled
  :commands (power-mode))

(use-package redacted
  :commands (redacted-mode)
  :straight (:host github :repo "bkaestner/redacted.el"))

(use-package zone
  :ensure nil
  :commands (zone)
  :config
  (setq original-zone-programs (copy-sequence zone-programs)))

