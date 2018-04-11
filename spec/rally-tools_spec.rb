require './rally-tools.rb'
describe RallyTools do
  describe ".get_rally_id_for_movie_name" do
    context "given a valid movie name" do
      it "returns an id" do
        expect(RallyTools.get_rally_id_for_movie_name("170368_001_TCCS_1833600_3")).to eql(89529)
      end
    end
  end

  describe ".get_metadata_for_movie_id" do
    context "given a valid movie id" do
      it "returns the movie's metadata" do
        expect(RallyTools.get_metadata_for_movie_id(89529)).to be_a(Hash)
      end
    end
  end
end
