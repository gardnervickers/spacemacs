;;; funcs.el --- rust Layer functions File for Spacemacs
;;
;; Copyright (c) 2012-2018 Sylvain Benner & Contributors
;;
;; Author: NJBS <DoNotTrackMeUsingThis@gmail.com>
;; URL: https://github.com/syl20bnr/spacemacs
;;
;; This file is not part of GNU Emacs.
;;
;;; License: GPLv3

(defun spacemacs/racer-describe ()
  "Show a *Racer Help* buffer for the function or type at point.
If `help-window-select' is non-nil, also select the help window."
  (interactive)
  (let ((window (racer-describe)))
    (when help-window-select
      (select-window window))))

(defun spacemacs/rust-quick-run ()
  "Quickly run a Rust file using rustc.
Meant for a quick-prototype flow only - use `spacemacs/open-junk-file' to
open a junk Rust file, type in some code and quickly run it.
If you want to use third-party crates, create a new project using `cargo-process-new' and run
using `cargo-process-run'."
  (interactive)
  (let ((input-file-name (buffer-file-name))
        (output-file-name (concat temporary-file-directory (make-temp-name "rustbin"))))
    (compile
     (format "rustc -o %s %s && %s"
             (shell-quote-argument output-file-name)
             (shell-quote-argument input-file-name)
             (shell-quote-argument output-file-name)))))

;; (use-package lsp-mode
;;   :config
;;   (lsp-register-client
;;    (make-lsp-client :new-connection "ra_lsp_mode"
;;                     :major-modes '(rust-mode rustic-mode)
;;                     :priority -1
;;                     :server-id 'rls
;;                     :notification-handlers (lsp-ht ("window/progress" 'lsp-clients--rust-window-progress))
;;                     :initialized-fn (lambda (workspace)
;;                                       (with-lsp-workspace workspace
;;                                         (lsp--set-configuration
;;                                          (lsp-configuration-section ")
(defcustom rust-analyzer-command '("ra_lsp_server")
  ""
  :type '(repeat (string)))

(defconst rust-analyzer--notification-handlers
  '(("rust-analyzer/publishDecorations" . (lambda (_w _p)))))

(defconst rust-analyzer--action-handlers
  '(("rust-analyzer.applySourceChange" .
     (lambda (p) (rust-analyzer--apply-source-change-command p)))))

(defun rust-analyzer--uri-filename (text-document)
  (lsp--uri-to-path (gethash "uri" text-document)))

(defun rust-analyzer--goto-lsp-loc (loc)
  (-let (((&hash "line" "character") loc))
    (goto-line (1+ line))
    (move-to-column character)))

(defun rust-analyzer--apply-text-document-edit (edit)
  "Like lsp--apply-text-document-edit, but it allows nil version."
  (let* ((ident (gethash "textDocument" edit))
         (filename (rust-analyzer--uri-filename ident))
         (version (gethash "version" ident)))
    (with-current-buffer (find-file-noselect filename)
      (when (or (not version) (= version (lsp--cur-file-version)))
        (lsp--apply-text-edits (gethash "edits" edit))))))

(defun rust-analyzer--apply-source-change (data)
  ;; TODO fileSystemEdits
  (seq-doseq (it (-> data (ht-get "workspaceEdit") (ht-get "documentChanges")))
    (rust-analyzer--apply-text-document-edit it))
  (-when-let (cursor-position (ht-get data "cursorPosition"))
    (let ((filename (rust-analyzer--uri-filename (ht-get cursor-position "textDocument")))
          (position (ht-get cursor-position "position")))
      (find-file filename)
      (rust-analyzer--goto-lsp-loc position))))

(defun rust-analyzer--apply-source-change-command (p)
  (let ((data (-> p (ht-get "arguments") (seq-first))))
    (rust-analyzer--apply-source-change data)))

(defun spacemacs//rust-initialize-rust-analyzer ()
  (use-package lsp-mode
    :defer t
    :config
    (progn
      (require 'lsp-clients)
      (require 'lsp)
      (require 'dash)
      (require 'ht)
      (lsp-register-client
       (make-lsp-client
        :new-connection (lsp-stdio-connection (lambda () rust-analyzer-command))
        :notification-handlers (ht<-alist rust-analyzer--notification-handlers)
        :action-handlers (ht<-alist rust-analyzer--action-handlers)
        :major-modes '(rust-mode rustic-mode)
        :priority 1
        :ignore-messages nil
        :server-id 'rust-analyzer
        ))
      (with-eval-after-load 'company-lsp
        ;; company-lsp provides a snippet handler for rust by default that adds () after function calls, which RA does better
        (setq company-lsp--snippet-functions (assq-delete-all "rust" company-lsp--snippet-functions)))


      ))
  )

(defun spacemacs//rust-setup-lsp ()
  "Setup lsp backend"
  (if (configuration-layer/layer-used-p 'lsp)
      (progn
        (spacemacs//rust-initialize-rust-analyzer)
        (lsp))
    (message "`lsp' layer is not installed, please add `lsp' layer to your dotfile."))
  (if (configuration-layer/layer-used-p 'dap)
      (progn
        (require 'dap-gdb-lldb)
        (spacemacs/dap-bind-keys-for-mode 'rust-mode))
    (message "`dap' layer is not installed, please add `dap' layer to your dotfile.")))

(defun spacemacs//rust-setup-racer ()
  "Setup racer backend"
  (progn
    (racer-mode)))

(defun spacemacs//rust-setup-backend ()
  "Conditionally setup rust backend."
  (pcase rust-backend
    (`racer (spacemacs//rust-setup-racer))
    (`lsp (spacemacs//rust-setup-lsp))))

(defun spacemacs//rust-setup-lsp-company ()
  "Setup lsp auto-completion."
  (if (configuration-layer/layer-used-p 'lsp)
      (progn
        (spacemacs|add-company-backends
          :backends company-lsp
          :modes rust-mode))
    (message "`lsp' layer is not installed, please add `lsp' layer to your dotfile.")))

(defun spacemacs//rust-setup-racer-company ()
  "Setup racer auto-completion."
        (spacemacs|add-company-backends
          :backends company-capf
          :modes rust-mode
          :variables company-tooltip-align-annotations t))

(defun spacemacs//rust-setup-company ()
  "Conditionally setup company based on backend."
  (pcase rust-backend
    (`racer (spacemacs//rust-setup-racer-company))
    (`lsp (spacemacs//rust-setup-lsp-company))))
