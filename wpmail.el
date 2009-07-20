;;; wpmail.el --- Post to wordpress by e-mail

;; Author: Thomas Kappler <tkappler@gmail.com>
;; Created: 2009 June 21
;; Keywords: wordpress, blog, blogging
;; URL: <http://github.com/thomas11/wpmail/tree/master>

;; Copyright (C) 2009 Thomas Kappler

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

;; A number of functions to make posting by e-mail to the
;; wordpress.com blog hosting service <http://www.wordpress.com>
;; easier.  It might work with other wordpress installations, which I
;; have not tried.  For more information about posting to wordpress by
;; e-mail see the support page
;; <http://support.wordpress.com/post-by-email/>.

;; Start a new post, possibly from the region or the buffer, with
;; wpmail-new-post, and send it with wpmail-send-post when you are
;; done.  wpmail-new-post will prompt for title and category; it will
;; propose some titles you can see via M-n, and auto-completes the
;; categories in wpmail-categories.  See the documentation of these
;; functions for details.

;; You must customize the following variables before you can use it.

(defconst wpmail-posts-dir "~/Documents/Blog/jugglingbits.wordpress.com/posts"
  "The directory where you store your blog posts.
New posts will be started in a new buffer visiting a file
there. You don't need to save the files at all, however.")

(defconst wpmail-post-email "FOO@post.wordpress.com"
  "The e-mail address you got from wordpress.com to send posts to.")

(defvar wpmail-categories '("Own Code" "Stuff" "Weekly Links" "Weekly Reading")
  "A list of the categories you use for blog posts.
When starting a new post, wpmail will ask you for the
category. These will be available for tab completion.  However,
you can also give a category that is not in this list.")

(defvar wpmail-default-tags "code,programming,testing"
  "A list of post tags that will appear whenever you start a new post.")

(defconst wpmail-category-is-also-tag t
  "Non-nil means that initially a post's category will also be one of its tags.")


;; Some helpers that might go into a more general library.
;; -------------------------------------------------------

(defun wpmail-trim (string)
  "Remove leading and trailing whitespace from STRING.
From http://www.math.umd.edu/~halbert/dotemacs.html."
  (replace-regexp-in-string "\\(^[ \t\n]*\\|[ \t\n]*$\\)" "" string))

(defun wpmail-options-for-post-title ()
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

;; End helpers -------------------------------------------

(defvar wpmail-post-title "wpmail.el post"
  "The post's title when sending it off.
Should be set via wpmail-new-post.")

(defun wpmail-new-post (title category init-content)
  "Start a new wordpress blog post.
The post will have the title TITLE and be in category CATEGORY.

The function proposes some titles based on the buffer name and
text around point, if any.  These propositions are in the
\"future history\", accessible by M-n.

In the category prompt, the values of wpmail-categories are
available for auto-completion.  However, you can also enter any
category that is not in wpmail-categories.

A new buffer will be created, visiting the file TITLE.wordpress
in wpmail-posts-dir.  There is no need to save this file,
however.  You can send it, with TITLE preserved, without saving
it.

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
		(read-string "Title: " nil nil (wpmail-options-for-post-title) nil)
		(completing-read "Category: " wpmail-categories)
		current-prefix-arg))
  (let ((content (if init-content (wpmail-buffer-or-region) nil)))
    (wpmail-initialize-new-post title category content)))

(defun wpmail-initialize-new-post (title category content)
  "Does the actual work after wpmail-new-post got the user's input."
  (unless content (setq content ""))
  (wpmail-create-and-show-new-post-buffer title category content)
  (set-visited-file-name (concat wpmail-posts-dir "/" title ".wordpress"))
  (set (make-local-variable 'wpmail-post-title) title))

(defun wpmail-create-and-show-new-post-buffer (title category content)
  "Create a new buffer named TITLE and initialize it."
  (let ((post-buffer (get-buffer-create title)))
    (set-buffer post-buffer)
    (goto-char (point-max))
    (insert "\n")
    (insert content)
    (insert (wpmail-initial-shortcodes category wpmail-default-tags))
    (goto-char (point-min))
    (switch-to-buffer post-buffer)))

(defun wpmail-initial-shortcodes (category tags)
  "Return the wordpress shortcodes as a string; see wpmail-new-post."
  (mapconcat 'identity 
	     (list
	      "\n"
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

; TODO do we need to require something mail-related here?
(defun wpmail-send-post ()
  "Send the post to wordpress.com by e-mail.
Partly copied from Trey Jackson
<http://stackoverflow.com/questions/679275/sending-email-in-emacs-programs>."
  (interactive)
  (let ((content (buffer-substring-no-properties (point-min) (point-max))))
    (message-mail wpmail-post-email wpmail-post-title)
    (message-goto-body)
    (insert content)
    (message-send-and-exit)))


(provide 'wpmail)
