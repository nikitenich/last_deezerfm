require 'lastfm'
require 'require_all'
require_relative 'constants'
require_rel 'lib'

lastfm = Lastfm.new(LASTFM_API_KEY, LASTFM_SECRET)
deezer = LastDeezerFm::Deezer.new(DEEZER_APP_ID, DEEZER_SECRET_KEY)
importer = LastDeezerFm::Importer.new(lastfm: lastfm, deezer: deezer, lastfm_user: LASTFM_USERNAME)
importer.lastfm_loved