;;; wpmail.el --- Post to wordpress by e-mail

;; Copyright (C) 2009 Thomas Kappler

;; Author: Thomas Kappler <tkappler@gmail.com>
;; Created: 2009 June 21
;; Keywords: comm, mail, wordpress, blog, blogging
;; URL: <http://github.com/thomas11/wpmail/tree/master>

;; This file is not part of GNU Emacs.

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; An Emacs extension to make posting by e-mail to the wordpress.com
;; blog hosting service <http://www.wordpress.com> easier.  It might
;; work with other wordpress installations, which I have not tried.
;; For more information about posting to wordpress by e-mail see the
;; support page <http://support.wordpress.com/post-by-email/>.

;; Documentation is a bit lacking, but here's the gist: start a new
;; post, possibly from the region or the buffer, with wpmail-new-post
;; or wpmail-new-post-here. Send it with wpmail-send-post when you are
;; done.  wpmail will prompt for title and category; it will propose
;; some titles that you can see via M-n, and it auto-completes the
;; categories in wpmail-categories.  See the documentation of these
;; functions for details.

;; You can write your posts in Markdown format
;; <http://daringfireball.net/projects/markdown/> if you have
;; markdown-mode <http://jblevins.org/projects/markdown-mode/>
;; installed. Set wpmail-markdown-command to your Markdown converter
;; and posts will be converted to HTML when sending them.

;;; Dependencies:
;; Message from Gnus.  It is included in Emacs, at least in version
;; 23.  Tested with Emacs 23 and Gnus v5.13.

;;; Installation:
;; Customize the variables at the top of the code section, and
;; (require 'wpmail) in your init file.

;;; History:
;; 2009-07:    First release.
;; 2009-11-03: Add post-configured-p and use it. Allow creating a new
;;   post in current buffer.
;; 2009-11-24: Add Markdown support.

;;; TODO

;; When proposing the file name for a title, remove suffixes.

;; Offer before- and after-send hooks, to allow things like
;; transforming the markup or saving all published posts in a certain
;; directory.

;; If you set wpmail-markdown-command, wpmail blindly assumes you use
;; Markdown for all your posts and will convert them all when sending
;; them off.

;;; Code:
(require 'message)

(defconst wpmail-posts-dir "~/Writing/Blog/jugglingbits.wordpress.com/posts"
  "The directory where you store your blog posts.
wpmail-new-post will open a new buffer visiting a file there.
Can be nil; you can always turn the current buffer into a blog
post with wpmail-new-post-here, and there is no need to save it
to a file.")

(defconst wpmail-post-email "FOO@post.wordpress.com"
  "The e-mail address you got from wordpress.com to send posts to.")

(defvar wpmail-categories '("Academia"
			    "Best Practices"
			    "Elsewhere"
			    "Links"
			    "Musings"
			    "Nitty Gritty"
			    "Own Code"
			    "Stuff"
			    "Theory")
  "A list of the categories you use for blog posts.
When starting a new post, wpmail will ask you for the category.
These will be available for tab completion.  You can also give a
category that is not in this list, but your wordpress must know
it.")

(defvar wpmail-default-tags "programming"
  "A list of post tags that will appear whenever you start a new post.")

(defvar wpmail-markdown-command "Markdown.pl")

(defvar wpmail-category-is-also-tag t
  "Non-nil means that initially a post's category will also be one of its tags.")

(defconst wpmail-cutoff-line
  "-- wpmail markdown cut-off, do not touch --"
  "A special line that marks the end of the actual post and the
  beginning of the wordpress shortcodes. Will not appear in
  posts.")


;; Some helpers that might go into a more general library.
;; -------------------------------------------------------

(defun wpmail-trim (string)
  "Remove leading and trailing whitespace from STRING.
From http://www.math.umd.edu/~halbert/dotemacs.html."
  (replace-regexp-in-string "\\(^[ \t\n]*\\|[ \t\n]*$\\)" "" string))

(defun wpmail-possible-titles ()
  "Make a list of suggestions for a blog post title.
The list contains at least the buffer name.  It also contains
some text around point, if it's not empty and not too long."
  (defun sensible-option-p (str)
    (and (stringp str) 
	 (< (length str) 60)
	 (> (length (wpmail-trim str)) 4)))

  (let ((options (list (buffer-name))))
    ;; Things at point
    (dolist (thing-kind (list 'word 'line 'sentence))
      (let ((option (thing-at-point thing-kind)))
    	(if (sensible-option-p option)
    	    (add-to-list 'options (wpmail-trim option)))))
    (delete-dups options)))

(defun wpmail-buffer-or-region ()
  "Return the region if it exists, the whole buffer otherwise."
  (if (use-region-p)
      (buffer-substring (region-beginning) (region-end))
    (buffer-substring (point-min) (point-max))))

;; End helpers ---------------------------------------------

(defun wpmail-new-post (title category init-content)
  "Start a new wordpress blog post in a new buffer.
The post will have the title TITLE and be in category CATEGORY.

The function proposes some titles based on the buffer name and
text around point, if any.  These propositions are in the
\"future history\", accessible by M-n.

In the category prompt, the values of wpmail-categories are
available for auto-completion.  You can also enter any category
that is not in wpmail-categories, but your wordpress must know
it.

A new buffer will be created, visiting the file TITLE.wp in
wpmail-posts-dir.  There is no need to save this file, however.
You can send it, with TITLE preserved, without saving it.

If INIT-CONTENT is non-nil (interactively, with prefix argument),
the new post buffer is filled with the region if it exists, and
with the whole content of the current buffer otherwise.

The new post buffer will contain a list of shortcodes, directives
the wordpress software evaluates when it receives the post. They
will be initialized to hopefully sensible values, but you should
check them before sending. In particular, you might wish to
change the post tags or the status. See
<http://support.wordpress.com/post-by-email/> for documentation
about shortcodes."
  (interactive (list 
		(read-string "Title: " nil nil (wpmail-possible-titles) nil)
		(completing-read "Category: " wpmail-categories)
		current-prefix-arg))
  (let ((content (if init-content (wpmail-buffer-or-region) nil)))
    (wpmail-initialize-new-file title category content)))

(defun wpmail-new-post-here (title category)
  "Start a new wordpress blog post in the current buffer.
It works like wpmail-new-post, except that everything happens in
the current buffer."
  (interactive (list 
		(read-string "Title: " nil nil (wpmail-possible-titles) nil)
		(completing-read "Category: " wpmail-categories)))
  (wpmail-initialize-this-buffer title category (point)))

(defun wpmail-initialize-new-file (title category content)
  "Does the actual work after wpmail-new-post got the user's input."
  (unless content (setq content ""))
  (wpmail-create-and-show-new-post-buffer title category content)
  (set-visited-file-name (wpmail-path-to-post-file title)))

(defun wpmail-path-to-post-file (title)
  "Find the path to a file with blog post TITLE.
The file will be in wpmail-posts-dir if non-nil, in the current
directory otherwise. If you write in Markdown, the suffix will be
.wp.md; otherwise just .wp."
  (let ((dir (if wpmail-posts-dir wpmail-posts-dir ".")))
    (concat dir "/" title ".wp" (when wpmail-markdown-command ".md"))))

(defun wpmail-create-and-show-new-post-buffer (title category content)
  "Create a new buffer named TITLE and initialize it."
  (let ((post-buffer (get-buffer-create title)))
    (set-buffer post-buffer)
    (wpmail-initialize-this-buffer title category (point-min))
    (switch-to-buffer post-buffer)))

(defun wpmail-initialize-this-buffer (title category restore-point)
  (let ((configured (wpmail-post-configured-p))
	(warning "This buffer seems to be initialized as a wordpress post already. New shortcodes will simply be added at the end. Continue?"))
    (when (or (not configured)
	      (y-or-n-p warning))
      (set (make-local-variable 'wpmail-post-title) title)
      (goto-char (point-max))
      (insert "\n\n"
	      (wpmail-initial-shortcodes category wpmail-default-tags))
      (goto-char restore-point))))

(defun wpmail-initial-shortcodes (category tags)
  "Return the wordpress shortcodes as a string; see wpmail-new-post."
  (mapconcat 'identity 
	     (list
              (when wpmail-markdown-command wpmail-cutoff-line)
	      (concat "[category " category "]")
	      (concat "[tags " tags 
		      (if wpmail-category-is-also-tag (concat "," category) "")
		      "]")
	      "[status draft]"
	      "-- "
	      "Anything after the signature line \"-- \" will not appear in the post."
	      "Status can be publish, pending, or draft."
	      "[slug some-url-name]"
	      "[excerpt]some excerpt[/excerpt]"
	      "[delay +1 hour]"
	      "[comments on | off]"
	      "[password secret-password]")
	     "\n"))

(defun wpmail-send-post ()
  "Send the post to wordpress.com by e-mail.
Partly copied from Trey Jackson
<http://stackoverflow.com/questions/679275/sending-email-in-emacs-programs>."
  (interactive)
  (let ((configured (wpmail-post-configured-p))
	(warning "This post doesn't seem to be configured yet; it lacks either a title or some wordpress shortcodes. (Initialize with wpmail-new-post-here.) Continue?"))
    (when (or configured (y-or-n-p warning))
      (let* ((buffer-content
              (buffer-substring-no-properties (point-min) (point-max)))
             (msg-body
              (if wpmail-markdown-command
                  (wpmail-markdown-to-html buffer-content)
                buffer-content)))
	(message-mail wpmail-post-email wpmail-post-title)
	(message-goto-body)
	(insert msg-body)
	(message-send-and-exit)))))

(defun wpmail-markdown-to-html (post)
  "Convert the current post from Markdown to HTML.
Returns the HTML in a string, the current buffer is not modified."
  (with-temp-buffer
    (insert post)
    (goto-char (point-min))
    (let ((end-of-post (wpmail-end-of-post)))
      (shell-command-on-region (point-min) end-of-post
                               wpmail-markdown-command t t)

      ;; Wordpress turns some line breaks into <br />. Grrr.
      (let ((fill-column 1000))
        (fill-region (point-min) end-of-post))

      (buffer-substring-no-properties (point-min) (point-max)))))

(defun wpmail-end-of-post ()
  "Find the end of the actual post, i.e., before the wordpress
shortcodes begin."
  (save-excursion
    (goto-char (point-min))
    (search-forward wpmail-cutoff-line nil t)
    (beginning-of-line)
    (kill-line)
    (point)))

(defun wpmail-post-configured-p ()
  "Determine whether we're ready to send the current buffer."
  (and (boundp 'wpmail-post-title)
       (save-excursion
	 (goto-char (point-min))
	 (search-forward "[status " nil t))))


;; Unit tests, using el-expectations by rubikitch,
;; <http://www.emacswiki.org/emacs/EmacsLispExpectations>.
;; ---------------------------------------------------------

(eval-when-compile
  (when (fboundp 'expectations)
    (expectations
     
      ;; helpers

      (desc "trim")
      (expect "foo"
	(wpmail-trim "foo"))
      (expect "foo"
	(wpmail-trim "foo "))
      (expect "foo"
	(wpmail-trim " foo "))
      (expect "foo bar"
	(wpmail-trim " foo bar "))
     ; That'd be nice, but doesn't work with el-expectations.
     ; (dolist foo '("foo" " foo" "foo " " foo ")
     ;         (expect "foo" (wpmail-trim foo)))

     (desc "possible-titles contains buffer name")
     (expect (non-nil)
       (memq (buffer-name) (wpmail-possible-titles)))
     
     ;; wpmail

     (desc "post-configured-p")
     (expect nil
       (with-temp-buffer 
	 (wpmail-post-configured-p)))
     (expect nil
       (with-temp-buffer 
	 (insert "[status draft]")
	 (wpmail-post-configured-p)))
     (expect (non-nil)
       (with-temp-buffer 
	 (set (make-local-variable 'wpmail-post-title) "title")
	 (insert "[status draft]")
	 (wpmail-post-configured-p)))

     (desc "initialize-this-buffer")
     (expect (non-nil)
       (with-temp-buffer 
	 (wpmail-initialize-this-buffer "title" "category" (point-min))
	 (wpmail-post-configured-p)))

     (desc "end of post")
     (expect 1
       (with-temp-buffer
         (insert wpmail-cutoff-line)
         (wpmail-end-of-post)))
     (expect 10
       (with-temp-buffer
         (insert "bla bla\n\n")
         (insert wpmail-cutoff-line)
         (wpmail-end-of-post))))))

;; End unit tests. -----------------------------------------


(provide 'wpmail)
;;; wpmail.el ends here
