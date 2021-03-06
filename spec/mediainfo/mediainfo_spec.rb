require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe MediaInfo do
  before(:all) do
    @mediainfo = MediaInfo.new(fixtures + "sample_mpeg4.mp4")
    @system_newline = $/.dup
  end

  # Avoid side effects from failing tests on newlines
  after(:each) do
    $/ = @system_newline
  end

  it "should raise an error when file doesn't exist" do
    -> { MediaInfo.new "will/not/exist.mkv" }.should raise_error(IOError, /unable to open file - .*will\/not\/exist\.mkv$/)
  end

  it "should provide access to all the track types" do
    [:video, :audio, :image, :chapters, :menu, :text].each { |type| @mediainfo.send(type).should be_an_instance_of(Array) }
  end

  it "should have an array of video tracks" do
    @mediainfo.video.all? { |t| t.should be_an_instance_of(MediaInfo::VideoTrack) }
    @mediainfo.video.count.should == 1
  end

  it "should have an array of audio tracks" do
    @mediainfo.audio.all? { |t| t.should be_an_instance_of(MediaInfo::AudioTrack) }
    @mediainfo.audio.count.should == 1
  end

  it "should dynamically create new track types depending on environment" do
    @mediainfo.instance_variable_get(:@bogus).should be_nil

    class ::MediaInfo::BogusTrack; end
    MediaInfo::TrackTypes << :bogus
    mediainfo = MediaInfo.new(fixtures + "sample_mpeg4.mp4")

    mediainfo.instance_variable_get(:@bogus).should be_an_instance_of(Array)

    MediaInfo::TrackTypes.delete :bogus
    MediaInfo.send :remove_const, :BogusTrack
  end

  describe "#track_info" do
    it "should complain if the stream type is not valid" do
      -> { @mediainfo.track_info nil, 0, 'Duration'}.should raise_error(ArgumentError)
      -> { @mediainfo.track_info :bogus, 0, 'Duration'}.should raise_error(ArgumentError)
      -> { @mediainfo.track_info [], 0, 'Duration'}.should raise_error(ArgumentError)
    end

    it "should return info for a track" do
      @mediainfo.track_info(:video, 0, 'Height').should == "240"
    end

    it "should return strings in utf-8" do
      @mediainfo.track_info(:video, 0, 'Height').encoding.should == Encoding::UTF_8
    end

    it "should accept a number as a parameter" do
      # Use @mediainfo.options("Info_Parameters")["Info_Parameters"] to see
      # mapping
      @mediainfo.track_info(:video, 0, 2).should == "1"
    end
  end

  describe "#options" do
    it "should work the class for global option setting" do
      MediaInfo.options "Internet" => "No"
      pending { MediaInfo.options("Internet")["Internet"].should == "1" }
    end

    it "should work on an instance for instance specific options" do
      @mediainfo.options "Internet" => "No"
      pending { @mediainfo.options("Internet")["Internet"].should == "1" }
    end

    it "should replace \\r with system newline terminators" do
      $/ = "\n"
      @mediainfo.options("Info_Codecs")["Info_Codecs"].should =~ /x263;Xirlink;4CC;V;;\n/
      $/ = "\r\n"
      @mediainfo.options("Info_Codecs")["Info_Codecs"].should =~ /x263;Xirlink;4CC;V;;\r\n/
    end

    it "should return option strings in utf-8" do
      @mediainfo.options("Info_Version")["Info_Version"].encoding.should == Encoding::UTF_8
    end
  end

  it "should output information in xml" do
    @mediainfo.to_xml.gsub($/, "\n").should == (fixtures + "sample_mpeg4.xml").read.strip
  end

  it "should output information in xml using system newlines" do
    $/ = "\r\n"
    @mediainfo.to_xml.should == (fixtures + "sample_mpeg4.xml").read.gsub("\n", "\r\n").strip
  end

  it "should output information in html" do
    pending
    @mediainfo.to_html.gsub($/, "\n").should == (fixtures + "sample_mpeg4.html").read
  end

  it "should output information in html using system newlines" do
    pending
    $/ = "\r\n"
    @mediainfo.to_html.should == (fixtures + "sample_mpeg4.html").read.gsub("\n", "\r\n")
  end

  it "should output information in a human readable format" do
    @mediainfo.to_s.gsub($/, "\n").should == (fixtures + "sample_mpeg4.txt").read.strip
  end

  it "should output information in a human readable format using system newlines" do
    $/ = "\r\n"
    @mediainfo.to_s.should == (fixtures + "sample_mpeg4.txt").read.gsub("\n", "\r\n").strip
  end

  it "should return information forms in utf-8" do
    warn "Test needs to be run in a non UTF-8 encoding to test. Try LANG=en_US.ASCII-7BIT rake spec" if __ENCODING__ == Encoding::UTF_8
    [@mediainfo.to_s, @mediainfo.to_xml, @mediainfo.to_html].each { |info| info.encoding.should == Encoding::UTF_8 }
  end

  it "should not use rb_str_new or rb_str_new2 because of encoding" do
    File.read(File.expand_path("../../../ext/mediainfo/mediainfo.cpp", __FILE__)).should_not include("rb_str_new")
  end

  it "should provide a shortcut to general properties" do
    @mediainfo.general.first.should_receive(:file)
    @mediainfo.general.first.should_receive(:duration)
    @mediainfo.general.first.should_receive(:size)
    @mediainfo.general.first.should_receive(:container)
    @mediainfo.general.first.should_receive(:mime_type)
    @mediainfo.general.first.should_receive(:size)
    @mediainfo.general.first.should_receive(:duration)
    @mediainfo.general.first.should_receive(:bitrate)
    @mediainfo.general.first.should_receive(:interleaved?)

    @mediainfo.file
    @mediainfo.duration
    @mediainfo.size
    @mediainfo.container
    @mediainfo.mime_type
    @mediainfo.size
    @mediainfo.duration
    @mediainfo.bitrate
    @mediainfo.interleaved?
  end

  it "should provide a shortcut to video properties" do
    @mediainfo.video.first.should_receive(:height)
    @mediainfo.video.first.should_receive(:width)
    @mediainfo.video.first.should_receive(:dar)
    @mediainfo.video.first.should_receive(:par)
    @mediainfo.video.first.should_receive(:codec)
    @mediainfo.video.first.should_receive(:frames)
    @mediainfo.video.first.should_receive(:ntsc?)
    @mediainfo.video.first.should_receive(:pal?)
    @mediainfo.video.first.should_receive(:interlaced?)

    @mediainfo.height
    @mediainfo.width
    @mediainfo.dar
    @mediainfo.par
    @mediainfo.video_codec
    @mediainfo.frames
    @mediainfo.ntsc?
    @mediainfo.pal?
    @mediainfo.interlaced?
  end

  it "should provide a shortcut to audio properties" do
    @mediainfo.audio.first.should_receive(:samplerate)
    @mediainfo.audio.first.should_receive(:codec)
    @mediainfo.audio.first.should_receive(:channels)

    @mediainfo.samplerate
    @mediainfo.audio_codec
    @mediainfo.channels
  end

  it "should have testers for existance of tracks" do
    @mediainfo.general?.should == !@mediainfo.general.empty?
    @mediainfo.video?.should == !@mediainfo.video.empty?
    @mediainfo.audio?.should == !@mediainfo.audio.empty?
    @mediainfo.image?.should == !@mediainfo.image.empty?
    @mediainfo.chapters?.should == !@mediainfo.chapters.empty?
    @mediainfo.text?.should == !@mediainfo.text.empty?
    @mediainfo.menu?.should == !@mediainfo.menu.empty?
  end

  it "should know how many tracks there are in total" do
    @mediainfo.tracks.count.should == 3 # 1 audio, 1 video, and 1 general
  end

  it "should allow the file to be closed and reopened" do
    @mediainfo.track_info(:video, 0, 'Height').should == "240"
    @mediainfo.close
    @mediainfo.track_info(:video, 0, 'Height').should == ""
    @mediainfo.open
    @mediainfo.track_info(:video, 0, 'Height').should == "240"
  end
end
