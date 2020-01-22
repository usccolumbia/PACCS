# -*- coding: utf-8 -*-
#
# paccs documentation build configuration file, created by
# sphinx-quickstart on Fri Jun 16 11:31:35 2017.
#
# This file is execfile()d with the current directory set to its
# containing dir.
#
# Note that not all possible configuration values are present in this
# autogenerated file.
#
# All configuration values have a default; values that are commented out
# serve to show the default.

# Add directory containing compiled SOs to the path
import os
import sys

sys.path.insert(0, os.path.abspath('../../lib'))

# Patch for Cython functions
def isfunction_cython_patch(candidate):
    return hasattr(type(candidate), '__code__')
import inspect
inspect.isfunction = isfunction_cython_patch

# Control whether private/other special members are documented
try:
    with open('../../.sphinx_document_all', 'r') as control_file:
        DOCUMENT_ALL = bool(int(control_file.read()))
except Exception:
    DOCUMENT_ALL = False

# -- General configuration ------------------------------------------------

# If your documentation needs a minimal Sphinx version, state it here.
#
# needs_sphinx = '1.0'

# Add any Sphinx extension module names here, as strings. They can be
# extensions coming with Sphinx (named 'sphinx.ext.*') or your custom
# ones.
extensions = ['sphinx.ext.autodoc',
    'sphinx.ext.doctest',
    'sphinx.ext.intersphinx',
    'sphinx.ext.todo',
    'sphinx.ext.coverage',
    'sphinx.ext.mathjax',
    'sphinx.ext.ifconfig',
    'sphinx.ext.napoleon',
    'sphinx.ext.viewcode',
    'sphinx.ext.autosummary',
]

autodoc_default_options = {}
autodoc_default_options["members"] = True
autodoc_default_options["show-inheritance"] = True
autodoc_default_options["special-members"] = True
if DOCUMENT_ALL:
    autodoc_default_options["private_members"] = True
    autodoc_default_options["undoc_members"] = True

# Add any paths that contain templates here, relative to this directory.
templates_path = ['_templates']

# The suffix(es) of source filenames.
# You can specify multiple suffix as a list of string:
#
# source_suffix = ['.rst', '.md']
source_suffix = '.rst'

# The master toctree document.
master_doc = 'index'

# General information about the project.
project = 'paccs'
copyright = '2017 Evan Pretti and Nathan A. Mahynski'
author = 'Evan Pretti and Nathan A. Mahynski'

# The version info for the project you're documenting, acts as replacement for
# |version| and |release|, also used in various other places throughout the
# built documents.
import paccs
# The short X.Y version.
version = paccs.version.version
# The full version, including alpha/beta/rc tags.
release = paccs.version.version

# The language for content autogenerated by Sphinx. Refer to documentation
# for a list of supported languages.
#
# This is also used if you do content translation via gettext catalogs.
# Usually you set "language" from the command line for these cases.
language = None

# List of patterns, relative to source directory, that match files and
# directories to ignore when looking for source files.
# This patterns also effect to html_static_path and html_extra_path
exclude_patterns = []

# The name of the Pygments (syntax highlighting) style to use.
pygments_style = 'sphinx'

# If true, `todo` and `todoList` produce output, else they produce nothing.
todo_include_todos = True


# -- Options for HTML output ----------------------------------------------

# The theme to use for HTML and HTML Help pages.  See the documentation for
# a list of builtin themes.
#
html_theme = 'sphinx_rtd_theme' #'nature'

# Theme options are theme-specific and customize the look and feel of a theme
# further.  For a list of options available for each theme, see the
# documentation.
#
# html_theme_options = {}

# Add any paths that contain custom static files (such as style sheets) here,
# relative to this directory. They are copied after the builtin static files,
# so a file named "default.css" will overwrite the builtin "default.css".
html_static_path = ['_static']


# -- Options for HTMLHelp output ------------------------------------------

# Output file base name for HTML help builder.
htmlhelp_basename = 'paccsdoc'


# -- Options for LaTeX output ---------------------------------------------

latex_elements = {
    # The paper size ('letterpaper' or 'a4paper').
    #
    # 'papersize': 'letterpaper',

    # The font size ('10pt', '11pt' or '12pt').
    #
    # 'pointsize': '10pt',

    # Additional stuff for the LaTeX preamble.
    #
    # 'preamble': '',

    # Latex figure (float) alignment
    #
    # 'figure_align': 'htbp',
}

# Grouping the document tree into LaTeX files. List of tuples
# (source start file, target name, title,
#  author, documentclass [howto, manual, or own class]).
latex_documents = [
    (master_doc, 'paccs.tex', 'paccs Documentation',
     'Evan Pretti and Nathan A. Mahynski', 'manual'),
]


# -- Options for manual page output ---------------------------------------

# One entry per manual page. List of tuples
# (source start file, name, description, authors, manual section).
man_pages = [
    (master_doc, 'paccs', 'paccs Documentation',
     [author], 1)
]


# -- Options for Texinfo output -------------------------------------------

# Grouping the document tree into Texinfo files. List of tuples
# (source start file, target name, title, author,
#  dir menu entry, description, category)
texinfo_documents = [
    (master_doc, 'paccs', 'paccs Documentation',
     author, 'paccs', 'Python crystal structure energy analysis toolkit.',
     'Miscellaneous'),
]




# Example configuration for intersphinx: refer to the Python standard library.
intersphinx_mapping = {
    'https://docs.python.org/2/': None,
    'https://docs.scipy.org/doc/numpy/': None,
    'https://docs.scipy.org/doc/scipy/reference/': None,
    'http://docs.enthought.com/mayavi/mayavi/': None,
    'http://cython.readthedocs.io/en/latest/': None
}