# Trudeau

Parses CBC Youtube videos to extract subtitles. This is then formatted nicely for human consumption

These notes are compiled and summarized by a human [here](https://www.notion.so/jnadeau/Covid-19-Canadian-PM-Trudeau-Summaries-9055578ceba94368a732b68904eae78f).

### To Run

1. Make sure a non-system Ruby is installed (I'm using 2.6.x)
1. Run `ruby captions.rb -h`
1. Run `ruby captions.rb -v VIDEO_ID` to parse a single video to STDOUT (Video ID is in the youtube URL. E.g. https://www.youtube.com/watch?v=VIDEO_ID)
1. Run `ruby captions.rb -t TOKEN` where token is a Google API token with the Youtube Data API enabled. This will parse the CBC playlist and output all files to the docs folder.
