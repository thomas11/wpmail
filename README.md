# wpmail.el --- Post to wordpress by e-mail

Copyright (C) 2009 Thomas Kappler

* Author: Thomas Kappler <tkappler@gmail.com>
* Created: 2009 June 21
* Keywords: comm, mail, wordpress, blog, blogging
* URL: <http://github.com/thomas11/wpmail/tree/master>

This file is not part of GNU Emacs.

Licensed under the [GPL version 3](http://www.gnu.org/licenses/) or later.

# Commentary

A number of functions to make posting by e-mail to the
wordpress.com blog hosting service <http://www.wordpress.com>
easier.  It might work with other wordpress installations, which I
have not tried.  For more information about posting to wordpress by
e-mail see the support page
<http://support.wordpress.com/post-by-email/>.

Start a new post, possibly from the region or the buffer, with
wpmail-new-post or wpmail-new-post-here. Send it with
wpmail-send-post when you are done.  wpmail will prompt for title
and category; it will propose some titles that you can see via M-n,
and it auto-completes the categories in wpmail-categories.  See the
documentation of these functions for details.

You can write your posts in Markdown format
<http://daringfireball.net/projects/markdown/> if you have
markdown-mode <http://jblevins.org/projects/markdown-mode/>
installed. Set wpmail-markdown-command to your Markdown converter
and posts will be converted to HTML when sending them.

# Dependencies
Message from Gnus.  It is included in Emacs, at least in version
23.  Tested with Emacs 23 and Gnus v5.13.

# Installation
Customize the variables at the top of the code section, and
(require 'wpmail) in your init file.

# History
* 2009-07:    First release.
* 2009-11-03: Add post-configured-p and use it. Allow creating a new
  post in current buffer.
* 2009-11-24: Add Markdown support.

# TODO

When proposing the file name for a title, remove suffixes.

Offer before- and after-send hooks, to allow things like
transforming the markup or saving all published posts in a certain
directory.

If you set wpmail-markdown-command, wpmail blindly assumes you use
Markdown for all your posts and will convert them all when sending
them off.


