require 'spec_helper'
require 'ecsex'

describe Ecsex::CLI do
  before do
  end

  it "should stdout sample" do
    output = capture_stdout do
      Ecsex::CLI.start(['help'])
    end
    output.should_not nil
  end

  it "include" do
    output = capture_stdout do
      Ecsex::CLI.start(['help', 'sample'])
    end
    output.should include('--fields')
  end

  after do
  end
end
