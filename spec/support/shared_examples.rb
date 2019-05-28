RSpec.shared_examples "async option passed to senders" do
  context "default value" do
    it "runs asynchronously" do
      expect(job_class).to receive(:perform_async)
      tracer.flush!
    end
  end

  context ":async is anything but a boolean with a value of 'false'" do
    it "runs asynchronously" do
      [nil, 0, "", " ", [], {}].each do |value|
        tracer = sender_class.new(options.merge(async: value))
        expect(job_class).to receive(:perform_async)
        tracer.flush!
      end
    end
  end

  context ":async is a boolean with a value of 'false'" do
    it "runs synchronously" do
      tracer = sender_class.new(options.merge(async: false))
      expect(job_class).to receive_message_chain(:new, :perform)
      tracer.flush!
    end
  end
end
