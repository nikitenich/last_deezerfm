require 'rest-client'
require 'lastfm'
require 'launchy'
require 'text'
require 'colorize'
require_relative 'lastfm_lib_extension'
require_relative 'constants'
require_relative 'deezer'
require_relative 'file_helper'
require_relative 'lastfm_to_deezer'
require_relative 'text_helper'

lastfm = Lastfm.new(LASTFM_API_KEY, LASTFM_SECRET)
deezer = LastDeezerFm::Deezer.new(DEEZER_APP_ID, DEEZER_SECRET_KEY)
importer = LastDeezerFm::Importer.new(lastfm: lastfm, deezer: deezer, lastfm_user: 'nikitenich')
importer.lastfm_loved