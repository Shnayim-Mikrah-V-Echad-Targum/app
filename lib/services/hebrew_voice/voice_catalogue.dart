/// Every open-source Hebrew voice that runs on the device, as the app offers
/// them (Settings, Accessibility, Hebrew voices): each one's files at a
/// fixed revision of its publisher's copy, with their sizes and digests, and
/// how its engine is fed.
///
/// Left out: Blue v1 (its symbol table is not published, so it can't be
/// given text), and the large models that need a server's GPU (Zonos, F5-TTS, Qwen,
/// Fish Speech, MOSS, NeuTTS, Mamre, HebTTS) or are published only as
/// PyTorch weights (MMS, Robo-Shaul). See docs/DESIGN.md.
library;

/// A file a voice is made of: [path] in [repo] at [revision], on Hugging
/// Face.
class VoiceFile {
  const VoiceFile(this.repo, this.revision, this.path, this.size, this.sha256);
  final String repo;
  final String revision;
  final String path;
  final int size;
  final String sha256;

  String get url => 'https://huggingface.co/$repo/resolve/$revision/$path';

  /// Its name on the device, which no other revision or file shares.
  String get localName => '${repo.replaceAll('/', '__')}@${revision.substring(0, 7)}/$path';

  @override
  bool operator ==(Object other) => other is VoiceFile && other.url == url;

  @override
  int get hashCode => url.hashCode;
}

const _phonikudRepo = 'Phonikud/phonikud-tts-checkpoints';
const _phonikudRevision = 'ff64ba389a3833c49a85c58fc51a7060a6984b87';
const _phonikudExpExportHand = VoiceFile(
  _phonikudRepo,
  _phonikudRevision,
  'auto_phonemize_exp/export_hand.onnx',
  63511038,
  '45d56d46dac0929b079c386cd28e11375d40712fb5b493f01606a4b793177330',
);
const _phonikudExpExportNonVocalized = VoiceFile(
  _phonikudRepo,
  _phonikudRevision,
  'auto_phonemize_exp/export_non_vocalized.onnx',
  63511038,
  '0f24198b26ef4b329bd343171f564d7b58ac02dbd810e5712f533db1e2e52f2f',
);
const _phonikudExpExportPhonikudEnhanced = VoiceFile(
  _phonikudRepo,
  _phonikudRevision,
  'auto_phonemize_exp/export_phonikud_enhanced.onnx',
  63511038,
  '0d850b8fe729b6b85f75a9a129db15b02ad7639824230bac7e13aa51f19523dc',
);
const _phonikudExpExportPhonikudNonEnhanced = VoiceFile(
  _phonikudRepo,
  _phonikudRevision,
  'auto_phonemize_exp/export_phonikud_non_enhanced.onnx',
  63511038,
  '840d619f77736a95a72ffa60f3557ab15d3eef230b99f0617cec179b34982356',
);
const _phonikudExpExportVocalized = VoiceFile(
  _phonikudRepo,
  _phonikudRevision,
  'auto_phonemize_exp/export_vocalized.onnx',
  63511038,
  '24a6a010012d85d85e92718db9f651842f5cab1aabf72ec927ccb8a4c25be6a1',
);
const _phonikudExpMapNonVocalized = VoiceFile(
  _phonikudRepo,
  _phonikudRevision,
  'auto_phonemize_exp/map_non_vocalized.json',
  431,
  'c806bb6cefaefb46163f610e654ce5ce99fffee373e7a1c1b008295c953d2393',
);
const _phonikudExpMapVocalized = VoiceFile(
  _phonikudRepo,
  _phonikudRevision,
  'auto_phonemize_exp/map_vocalized.json',
  664,
  '142a62c540a5e682449459078d6ac531514eb5816daf62f02785a6b5743e3f9d',
);
const _phonikudMichael = VoiceFile(
  _phonikudRepo,
  _phonikudRevision,
  'michael.onnx',
  63516050,
  'd2824d46ecd7ca8a206686d818d3178effe4661ce78bdb4e754eed32fe604320',
);
const _phonikudModelConfig = VoiceFile(
  _phonikudRepo,
  _phonikudRevision,
  'model.config.json',
  7073,
  '7f790dce7e26969a535ecda2715cc7da9c5261269cbf11c213d107b611458679',
);
const _phonikudModel = VoiceFile(_phonikudRepo, _phonikudRevision, 'model.onnx', 63511038, 'dfe0a8f33002654fa560c4cdb796d934b6aa84b3bfb16779646a5b0f1bd9d968');
const _phonikudShaul = VoiceFile(_phonikudRepo, _phonikudRevision, 'shaul.onnx', 63516050, '7bcbd364b0bc357df8ef6c7c873e48f22897df16ec6c9d8f9d7ef792f6ae03c9');
const _phonikudShaulWhisperHebIpa1 = VoiceFile(
  _phonikudRepo,
  _phonikudRevision,
  'shaul_whisper_heb_ipa1.onnx',
  63511038,
  '592363804a09e3d70b05bd86b366e12e0a12c4a4d0100997cf8f0832132c55e7',
);
const _noaRepo = 'thewh1teagle/piper-he-noa';
const _noaRevision = '23f8e06909e9a1e562a50f99df63e3785451379a';
const _noaHeILNoaMedium = VoiceFile(
  _noaRepo,
  _noaRevision,
  'he_IL-noa-medium.onnx',
  77056101,
  '83b18c0b8fad6ac00fcea5c5bdf3c1fdbec182f9eadad9f97bc423ab4e22be7d',
);
const _noaHeILNoaMediumConfig = VoiceFile(
  _noaRepo,
  _noaRevision,
  'he_IL-noa-medium.onnx.json',
  5048,
  '109a7a2a0739061510f318d987e81c27ba81ca57c9303444298f712f71b1082c',
);
const _phonikudMediumRepo = 'notmax123/piper-medium-heb';
const _phonikudMediumRevision = '159c04c325df208e2045d929f11a25015942729a';
const _phonikudMediumModelConfig = VoiceFile(
  _phonikudMediumRepo,
  _phonikudMediumRevision,
  'model.config.json',
  8276,
  '0628eb7c696ff89b3ef64f4ec022a0b61278ef3b72bf62dd21b577f013854708',
);
const _phonikudMediumPiperMediumFemale = VoiceFile(
  _phonikudMediumRepo,
  _phonikudMediumRevision,
  'piper_medium_female.onnx',
  63461522,
  '7d98362e29e68785637549713901b4c38094719ae8d094056df8c52cf91c0cec',
);
const _phonikudMediumPiperMediumMale = VoiceFile(
  _phonikudMediumRepo,
  _phonikudMediumRevision,
  'piper_medium_male.onnx',
  63461522,
  '9971617aaa8786aea27325ac458fc4371d54af0d4316c2002b76789806cb2090',
);
const _kokoroRepo = 'thewh1teagle/kokoro-hebrew-nc';
const _kokoroRevision = '07e2334fc252d7965cb8dbd503bf7565bad71228';
const _kokoroConfig = VoiceFile(_kokoroRepo, _kokoroRevision, 'config.json', 2526, '042f62ac55870757c2945a3a8d4b7fb01a9f9f775c12b1ef09f41fef1efd24f5');
const _kokoroKokoro = VoiceFile(_kokoroRepo, _kokoroRevision, 'kokoro.onnx', 325505393, '6b9b16fbba87fec17a21cd3b11203286e1e657014dbab236703fdf0cf13a9a2f');
const _kokoroVoicesHebrew = VoiceFile(
  _kokoroRepo,
  _kokoroRevision,
  'voices-hebrew.bin',
  522510,
  '5efaa05741532c144a535677f02e02fd72c76fd8ec45840d6e3194b38194e9a7',
);
const _blueV3Repo = 'notmax123/BlueV3-onnx';
const _blueV3Revision = 'b26faaa63255d2991998c7f28c10aa4e6026f3c9';
const _blueV3DurationPredictor = VoiceFile(
  _blueV3Repo,
  _blueV3Revision,
  'duration_predictor.onnx',
  3700147,
  'c3eb91414d5ff8a7a239b7fe9e34e7e2bf8a8140d8375ffb14718b1c639325db',
);
const _blueV3Stats = VoiceFile(_blueV3Repo, _blueV3Revision, 'stats.npz', 1920, '9ce8b62e010a4548404895824a96c3edf004943c349f7397399b2eac03d726e5');
const _blueV3TextEncoder = VoiceFile(
  _blueV3Repo,
  _blueV3Revision,
  'text_encoder.onnx',
  28117514,
  '814abd18767806852e872618f7bafdb032d5ea795dab3d5597ec9be2de8ebeaa',
);
const _blueV3Tts = VoiceFile(_blueV3Repo, _blueV3Revision, 'tts.json', 8313, 'fdfb2525307949ce7dcf5278402e945c36c9baa029371570652dc14d9c0ba26a');
const _blueV3VectorEstimator = VoiceFile(
  _blueV3Repo,
  _blueV3Revision,
  'vector_estimator.onnx',
  256515586,
  '3d3d3d56c23326c6a9fcae50ad3d3bd480ed52e3a9cdca00c76279a4d56ffe14',
);
const _blueV3Vocoder = VoiceFile(_blueV3Repo, _blueV3Revision, 'vocoder.onnx', 101414687, 'd4b2ce0f5d88a31f161a5881d076311c05f68672d09355ee9bb110eafcdc0a68');
const _blueV3VoiceRoi = VoiceFile(_blueV3Repo, _blueV3Revision, 'voices/Roi.json', 296585, 'e7580c4b718c11e25a5999c0ae9c5467e0f58c667c560f001219d300effed94e');
const _blueV3VoiceRotem = VoiceFile(
  _blueV3Repo,
  _blueV3Revision,
  'voices/Rotem.json',
  298072,
  'b8f3416cf1eaf047657981ba1ee1997819108ab0a42afd1f846f29a4eab8c4ae',
);
const _blue2Repo = 'notmax123/blue-onnx-v2';
const _blue2Revision = '45dc85f1ac045ea62458a7492c5ae387610ac0af';
const _blue2DurationPredictor = VoiceFile(
  _blue2Repo,
  _blue2Revision,
  'duration_predictor.onnx',
  1486789,
  '1fb897a3f1c5f4132ffba3e56c5792f8c03783e2f478d825774514da668af161',
);
const _blue2TextEncoder = VoiceFile(
  _blue2Repo,
  _blue2Revision,
  'text_encoder.onnx',
  27388430,
  '9f80f87093067ee2300343133b0456e36d705eea31f523f9d3dc9f4c5e212db1',
);
const _blue2Tts = VoiceFile(_blue2Repo, _blue2Revision, 'tts.json', 8744, '9afc8622ee9a40adff8befdc6bdfcb3c008f8caed9750febe870e53f47a73a0a');
const _blue2VectorEstimator = VoiceFile(
  _blue2Repo,
  _blue2Revision,
  'vector_estimator.onnx',
  142098194,
  '8c333ef2eb0c075136384eaa9608a374230f1b26e8181097467b803078095a5a',
);
const _blue2Vocab = VoiceFile(_blue2Repo, _blue2Revision, 'vocab.json', 3568, '9c5ce360977b8b70423a782519bc067681863aae54768105e5aa0fed9f02520d');
const _blue2Vocoder = VoiceFile(_blue2Repo, _blue2Revision, 'vocoder.onnx', 101374377, 'f4fbb6f60dec035cd8071883e021ac2cd3eee62630e42174492fd2d1f39976db');
const _blue2VoiceFemale1 = VoiceFile(
  _blue2Repo,
  _blue2Revision,
  'voices/female1.json',
  291230,
  '22e6c98210ca014cfd40bd485152a58c49bfff32265faff8c1c47cb4d60e1872',
);
const _blue2VoiceMale1 = VoiceFile(_blue2Repo, _blue2Revision, 'voices/male1.json', 291663, '82a85332d7640a524868a0c5a3b9b4eac502d80a5cca52f7a1f5994d687f50bb');
const _blue2Int8Repo = 'notmax123/bluev2-onnx-int8';
const _blue2Int8Revision = '5f715c98cd96b1e88bce9ddfc18c709f7bb7e954';
const _blue2Int8DurationPredictor = VoiceFile(
  _blue2Int8Repo,
  _blue2Int8Revision,
  'duration_predictor.onnx',
  592545,
  'e751ef9f96fdaf25d5c6249614414cb62667b7f2ddd9daa6f551658af137d8f7',
);
const _blue2Int8TextEncoder = VoiceFile(
  _blue2Int8Repo,
  _blue2Int8Revision,
  'text_encoder.onnx',
  7198671,
  '4cf8228a029d6d7e1512176e3146200bec1643ef8f1c21693053fed19c56ffec',
);
const _blue2Int8Tts = VoiceFile(_blue2Int8Repo, _blue2Int8Revision, 'tts.json', 8744, '9afc8622ee9a40adff8befdc6bdfcb3c008f8caed9750febe870e53f47a73a0a');
const _blue2Int8VectorEstimator = VoiceFile(
  _blue2Int8Repo,
  _blue2Int8Revision,
  'vector_estimator.onnx',
  45814014,
  'ab9c7b577c101719f39fe2ae9103595b9cd18cbd300524949dd95cd863b56093',
);
const _blue2Int8Vocab = VoiceFile(_blue2Int8Repo, _blue2Int8Revision, 'vocab.json', 3568, '9c5ce360977b8b70423a782519bc067681863aae54768105e5aa0fed9f02520d');
const _blue2Int8Vocoder = VoiceFile(
  _blue2Int8Repo,
  _blue2Int8Revision,
  'vocoder.onnx',
  25644477,
  '846d13fa9f45bbba17ed503608b80b88753942f556e65bf83e436ae87a5a4f6a',
);
const _pocketRepo = 'thewh1teagle/pocket-tts-onnx';
const _pocketRevision = '110f5251188e9407b4f724acdd8b0dfd0b20692a';
const _pocketModel = VoiceFile(_pocketRepo, _pocketRevision, 'he/model.onnx', 176992315, '010c6701d007277e6b37440b909de098200802fddbe70f74e890763b5dd43745');
const _pocketAssets = VoiceFile(_pocketRepo, _pocketRevision, 'he/assets.json', 1654421, '82db670c52c35d0dd9440339af0a02269b8e19f9531c97673b0f2244d37a9b23');
const _blue25Repo = 'notmax123/BlueTTS2.5-onnx';
const _blue25Revision = '468da64b4a51795a7594a3637727dbaf876b6df2';
const _blue25DurationPredictorStyle = VoiceFile(
  _blue25Repo,
  _blue25Revision,
  'duration_predictor_style.onnx',
  1508749,
  '3d0347cfc09234b78a20d5fa50b5c402d338fb99825f40ada8c70301edbb60ea',
);
const _blue25Stats = VoiceFile(_blue25Repo, _blue25Revision, 'stats.npz', 1920, '20d44fae010d46b859ee6238609780eb7bd5bf82320bad17b826a5dcfa4ed658');
const _blue25TextEncoder = VoiceFile(
  _blue25Repo,
  _blue25Revision,
  'text_encoder.onnx',
  27419694,
  'f971aa25315b93efff1850b39fe293aa93ae85df69fabf5e5022318cc632973c',
);
const _blue25Tts = VoiceFile(_blue25Repo, _blue25Revision, 'tts.json', 9260, '862d44194197de4873eccc8bfdab1835d15f98e469a90489df6da8f92a48c7ea');
const _blue25Uncond = VoiceFile(_blue25Repo, _blue25Revision, 'uncond.npz', 52732, '1c71c2b2836fd97f4c56eb21e258227650bbe0dcd906f64e2bba58e6ac09e76b');
const _blue25VectorEstimator = VoiceFile(
  _blue25Repo,
  _blue25Revision,
  'vector_estimator.onnx',
  132475789,
  '50557b34acfafa4b34f21dae263faa74d3f3169f114ff927599a1eff110d0b6e',
);
const _blue25Vocab = VoiceFile(_blue25Repo, _blue25Revision, 'vocab.json', 3157, '13fba5e735222fcf30d9c062d898982a1ba86d481f11560fbbdf6e0af79417b3');
const _blue25Vocoder = VoiceFile(_blue25Repo, _blue25Revision, 'vocoder.onnx', 101411919, 'b0709df316ff44cc263c04fbf9d17371b16897071a48b79d3634d5f379fb3067');
const _blue25VoiceLibriFemale1088 = VoiceFile(
  _blue25Repo,
  _blue25Revision,
  'voices/libri_female_1088.json',
  288994,
  'f3d5015c918b33c6cf6530b5a12e836a09179dd88df59d50332ff7b0be6507d8',
);
const _blue25VoiceLibriFemale6147 = VoiceFile(
  _blue25Repo,
  _blue25Revision,
  'voices/libri_female_6147.json',
  289185,
  'f77529b5eafa8c6e4835e55f2d654f08135d5511349a56afcbcbed4f7310e0ed',
);
const _blue25VoiceLibriMale6209 = VoiceFile(
  _blue25Repo,
  _blue25Revision,
  'voices/libri_male_6209.json',
  289115,
  'b3002eb671627ce4ce3dbad08ddf1cad1ac19d2307e846ca5bc08784efe693f1',
);
const _blue25VoiceLibriMale8088 = VoiceFile(
  _blue25Repo,
  _blue25Revision,
  'voices/libri_male_8088.json',
  288870,
  '3ad60cb68f8838dc00bacac968d55fd8469c1453283f27a210e15114671fb240',
);

/// How a voice's model is fed and run.
sealed class VoiceSpec {
  const VoiceSpec();

  /// Every file it needs, the model's and the voice's.
  List<VoiceFile> get files;

  /// The file that makes it this voice and no other of its model: its model,
  /// or for a model of many voices, its style.
  VoiceFile get own;

  /// What its voices share once open: its model (a Blue model's voices are
  /// one model, given each one's style as it reads).
  String get modelKey => own.url;
}

/// How a Piper model reads: the sounds with a pad after each (as Piper
/// trains), the sounds alone, or the letters themselves (an experiment of
/// Phonikud's), pointed or bare.
enum PiperInput { sounds, soundsUnpadded, pointedLetters, bareLetters }

/// A Piper (VITS) voice: one pass from symbols to audio, at 22,050 Hz.
class PiperSpec extends VoiceSpec {
  const PiperSpec({
    required this.model,
    required this.config,
    this.letters,
    this.input = PiperInput.sounds,
    this.speaker,
    this.noise = 0.4,
    this.length = 1.0,
    this.noiseWidth = 0.5,
  });
  final VoiceFile model;

  /// Its Piper config, whose phoneme_id_map turns symbols into ids.
  final VoiceFile config;

  /// For [PiperInput.pointedLetters] and [PiperInput.bareLetters], the map
  /// from each letter and point to the symbol it was trained as.
  final VoiceFile? letters;
  final PiperInput input;

  /// The speaker of a model of several (Noa, of Noa and LJSpeech).
  final int? speaker;

  /// The voice's variation of sound, pace and variation of timing. Less
  /// variation than Piper's own (0.667 and 0.8): every voice read more
  /// clearly with it, and more steadily, in the app's test.
  final double noise;
  final double length;
  final double noiseWidth;

  @override
  List<VoiceFile> get files => [model, config, ?letters];

  @override
  VoiceFile get own => model;
}

/// A Kokoro (StyleTTS 2) voice: one pass, from sounds and a style chosen by
/// their number, at 24,000 Hz.
class KokoroSpec extends VoiceSpec {
  const KokoroSpec({required this.model, required this.config, required this.styles, required this.style});
  final VoiceFile model;

  /// Its config, whose vocab turns sounds into ids.
  final VoiceFile config;

  /// The styles, an .npz of one array per voice.
  final VoiceFile styles;

  /// This voice's array in [styles].
  final String style;

  @override
  List<VoiceFile> get files => [model, config, styles];

  @override
  VoiceFile get own => model;
}

/// A Blue voice: flow matching from noise to the voice's latents, guided by
/// the sounds and the voice's style, then a vocoder, at 44,100 Hz.
class BlueSpec extends VoiceSpec {
  const BlueSpec({
    required this.durationPredictor,
    required this.textEncoder,
    required this.vectorEstimator,
    required this.vocoder,
    required this.vocab,
    required this.config,
    required this.style,
    this.stats,
    this.uncond,
    this.guidance = BlueGuidance.input,
    this.foldLatent = false,
  });
  final VoiceFile durationPredictor;
  final VoiceFile textEncoder;
  final VoiceFile vectorEstimator;
  final VoiceFile vocoder;

  /// Its vocab, which turns sounds into ids.
  final VoiceFile vocab;

  /// Its tts.json: the sample rate and the latents' geometry.
  final VoiceFile config;

  /// The voice: its style for the acoustic model and for the duration.
  final VoiceFile style;

  /// Where the vocoder takes the de-normalized latent, the latents' mean
  /// and deviation.
  final VoiceFile? stats;

  /// Where guidance is the runtime's to do, the unconditional embeddings.
  final VoiceFile? uncond;
  final BlueGuidance guidance;

  /// Whether the vocoder takes the latent unfolded, [1, 24, 6T] for
  /// [1, 144, T].
  final bool foldLatent;

  @override
  List<VoiceFile> get files => [durationPredictor, textEncoder, vectorEstimator, vocoder, vocab, config, style, ?stats, ?uncond];

  @override
  VoiceFile get own => style;

  @override
  String get modelKey => vectorEstimator.url;
}

/// A Pocket TTS voice (Kyutai's model, with thewh1teagle's Hebrew adapter):
/// a streaming model that makes 80 ms of audio a step, at 24,000 Hz.
class PocketSpec extends VoiceSpec {
  const PocketSpec({required this.model, required this.assets, required this.voice});
  final VoiceFile model;

  /// Its config, its voices and its tokenizer.
  final VoiceFile assets;

  /// This voice's conditioning in [assets].
  final String voice;

  @override
  List<VoiceFile> get files => [model, assets];

  /// Its voices are all in [assets].
  @override
  VoiceFile get own => assets;

  @override
  String get modelKey => model.url;
}

/// How a Blue model is guided toward the text (classifier-free guidance).
enum BlueGuidance {
  /// The vector estimator takes a cfg_scale input.
  input,

  /// It is guided inside the graph already, at its own strength.
  inGraph,

  /// The runtime blends a conditional and an unconditional step.
  runtime,
}

enum VoiceGender { male, female }

enum VoiceSpeed { quick, moderate, slow }

/// Who made a voice, and where it was trained: for its description and its
/// credit (Sources & accuracy).
enum VoiceFamily {
  /// Phonikud TTS (Piper), trained on SASPEECH: non-commercial (CC BY-NC).
  phonikud('https://huggingface.co/Phonikud/phonikud-tts-checkpoints', VoiceLicence.nonCommercial),

  /// Noa (Piper), by thewh1teagle: CC BY 4.0.
  noa('https://huggingface.co/thewh1teagle/piper-he-noa', VoiceLicence.attribution),

  /// Piper medium voices by notmax123: CC BY-NC 4.0.
  phonikudMedium('https://huggingface.co/notmax123/piper-medium-heb', VoiceLicence.nonCommercial),

  /// Kokoro Hebrew, converted by thewh1teagle from avris's SASPEECH model:
  /// non-commercial.
  kokoro('https://huggingface.co/thewh1teagle/kokoro-hebrew-nc', VoiceLicence.nonCommercial),

  /// BlueTTS by notmax123 (Max Melichov): MIT.
  blue('https://github.com/maxmelichov/BlueTTS', VoiceLicence.mit),

  /// Kyutai's Pocket TTS, with thewh1teagle's Hebrew adapter: CC BY 4.0.
  pocket('https://huggingface.co/thewh1teagle/pocket-tts-onnx', VoiceLicence.attribution);

  const VoiceFamily(this.source, this.licence);
  final String source;
  final VoiceLicence licence;
}

enum VoiceLicence { mit, attribution, nonCommercial }

/// Where a voice is listed among the others.
enum VoiceGroup {
  /// The clearest, listed first.
  recommended,

  /// The rest that read well.
  more,

  /// Phonikud's experiments, other trainings of one voice: some read worse.
  experimental,
}

/// One voice the reader can choose.
class HebrewVoiceOption {
  const HebrewVoiceOption({
    required this.id,
    required this.name,
    required this.nameHe,
    required this.gender,
    required this.family,
    required this.spec,
    required this.clarity,
    required this.normalSpeed,
    this.group = VoiceGroup.more,
    this.model,
  });

  /// Kept in the settings: never changed once released.
  final String id;

  /// Its name, in English and Hebrew.
  final String name;
  final String nameHe;
  final VoiceGender gender;
  final VoiceFamily family;
  final VoiceSpec spec;

  /// How much of what it read the app's test heard right (the consonants of
  /// fourteen verses, by a Hebrew speech recognizer), from 0 to 1.
  final double clarity;

  /// The speed, 1 being its own pace, at which it reads [kReadingPace], as
  /// the app's test found: at their own, the voices read between 5 and 8
  /// syllables a second, as fast as people talk.
  final double normalSpeed;
  final VoiceGroup group;

  /// What the model is, where a family has several ("Blue V3", "Kokoro").
  final String? model;

  List<VoiceFile> get files => spec.files;

  /// How long it takes to make what it reads, by its kind of model, as the
  /// app's test found: Piper a tenth of the speech's length, Kokoro and Blue
  /// a quarter to two fifths, Pocket TTS longer than the speech itself on a
  /// laptop, so that Listen may pause between verses.
  VoiceSpeed get speed => switch (spec) {
        PiperSpec() => VoiceSpeed.quick,
        KokoroSpec() || BlueSpec() => VoiceSpeed.moderate,
        PocketSpec() => VoiceSpeed.slow,
      };

  /// What it all takes on the device.
  int get bytes => {for (final f in files) f.url: f.size}.values.fold(0, (a, b) => a + b);
}

PiperSpec _phonikudVoice(VoiceFile model, {VoiceFile? letters, PiperInput input = PiperInput.sounds}) =>
    PiperSpec(model: model, config: _phonikudModelConfig, letters: letters, input: input);

BlueSpec _blueV3(VoiceFile style) => BlueSpec(
  durationPredictor: _blueV3DurationPredictor,
  textEncoder: _blueV3TextEncoder,
  vectorEstimator: _blueV3VectorEstimator,
  vocoder: _blueV3Vocoder,
  vocab: _blue2Vocab,
  config: _blueV3Tts,
  style: style,
  stats: _blueV3Stats,
  guidance: BlueGuidance.inGraph,
);

BlueSpec _blue2(VoiceFile style) => BlueSpec(
  durationPredictor: _blue2DurationPredictor,
  textEncoder: _blue2TextEncoder,
  vectorEstimator: _blue2VectorEstimator,
  vocoder: _blue2Vocoder,
  vocab: _blue2Vocab,
  config: _blue2Tts,
  style: style,
);

BlueSpec _blue2Int8(VoiceFile style) => BlueSpec(
  durationPredictor: _blue2Int8DurationPredictor,
  textEncoder: _blue2Int8TextEncoder,
  vectorEstimator: _blue2Int8VectorEstimator,
  vocoder: _blue2Int8Vocoder,
  vocab: _blue2Int8Vocab,
  config: _blue2Int8Tts,
  style: style,
);

BlueSpec _blue25(VoiceFile style) => BlueSpec(
  durationPredictor: _blue25DurationPredictorStyle,
  textEncoder: _blue25TextEncoder,
  vectorEstimator: _blue25VectorEstimator,
  vocoder: _blue25Vocoder,
  vocab: _blue25Vocab,
  config: _blue25Tts,
  style: style,
  stats: _blue25Stats,
  uncond: _blue25Uncond,
  guidance: BlueGuidance.runtime,
  foldLatent: true,
);

/// The voice Listen reads with until the reader chooses another: as clear as
/// the clearest in the app's test, and quick enough (a tenth of a verse's
/// length to make it) to keep ahead of the reading on any phone or browser.
const kDefaultHebrewVoice = 'phonikud-michael';

/// How fast every voice reads at the pace Listen calls normal: three and a
/// half syllables a second, slow enough to follow the words in the text,
/// where people talk at five to seven.
const kReadingPace = 3.5;

/// Every voice, clearest first within each group.
final List<HebrewVoiceOption> hebrewVoices = List.unmodifiable([
  // Recommended.
  HebrewVoiceOption(
    id: 'blue25-male-6209',
    name: 'Reader 6209',
    nameHe: 'קורא 6209',
    gender: VoiceGender.male,
    family: VoiceFamily.blue,
    model: 'Blue 2.5',
    spec: _blue25(_blue25VoiceLibriMale6209),
    clarity: 0.976,
    normalSpeed: 0.56,
    group: VoiceGroup.recommended,
  ),
  HebrewVoiceOption(
    id: 'blue25-female-1088',
    name: 'Reader 1088',
    nameHe: 'קוראת 1088',
    gender: VoiceGender.female,
    family: VoiceFamily.blue,
    model: 'Blue 2.5',
    spec: _blue25(_blue25VoiceLibriFemale1088),
    clarity: 0.973,
    normalSpeed: 0.562,
    group: VoiceGroup.recommended,
  ),
  HebrewVoiceOption(
    id: 'blue2-int8-female1',
    name: 'Female 1',
    nameHe: 'קול נשי 1',
    gender: VoiceGender.female,
    family: VoiceFamily.blue,
    model: 'Blue 2, compact',
    spec: _blue2Int8(_blue2VoiceFemale1),
    clarity: 0.973,
    normalSpeed: 0.572,
    group: VoiceGroup.recommended,
  ),
  HebrewVoiceOption(
    id: 'blue2-int8-male1',
    name: 'Male 1',
    nameHe: 'קול גברי 1',
    gender: VoiceGender.male,
    family: VoiceFamily.blue,
    model: 'Blue 2, compact',
    spec: _blue2Int8(_blue2VoiceMale1),
    clarity: 0.972,
    normalSpeed: 0.576,
    group: VoiceGroup.recommended,
  ),
  HebrewVoiceOption(
    id: 'kokoro-shaul',
    name: 'Shaul',
    nameHe: 'שאול',
    gender: VoiceGender.male,
    family: VoiceFamily.kokoro,
    model: 'Kokoro',
    spec: KokoroSpec(model: _kokoroKokoro, config: _kokoroConfig, styles: _kokoroVoicesHebrew, style: 'he_shaul'),
    clarity: 0.972,
    normalSpeed: 0.542,
    group: VoiceGroup.recommended,
  ),
  HebrewVoiceOption(
    id: kDefaultHebrewVoice,
    name: 'Michael',
    nameHe: 'מיכאל',
    gender: VoiceGender.male,
    family: VoiceFamily.phonikud,
    model: 'Piper',
    spec: _phonikudVoice(_phonikudMichael),
    clarity: 0.972,
    normalSpeed: 0.531,
    group: VoiceGroup.recommended,
  ),
  HebrewVoiceOption(
    id: 'noa',
    name: 'Noa',
    nameHe: 'נועה',
    gender: VoiceGender.female,
    family: VoiceFamily.noa,
    model: 'Piper',
    spec: PiperSpec(model: _noaHeILNoaMedium, config: _noaHeILNoaMediumConfig, speaker: 0),
    clarity: 0.97,
    normalSpeed: 0.541,
    group: VoiceGroup.recommended,
  ),
  HebrewVoiceOption(
    id: 'piper-medium-female',
    name: 'Female',
    nameHe: 'קול נשי',
    gender: VoiceGender.female,
    family: VoiceFamily.phonikudMedium,
    model: 'Piper',
    spec: PiperSpec(model: _phonikudMediumPiperMediumFemale, config: _phonikudMediumModelConfig, input: PiperInput.soundsUnpadded),
    clarity: 0.968,
    normalSpeed: 0.529,
    group: VoiceGroup.recommended,
  ),
  // More.
  HebrewVoiceOption(
    id: 'blue2-female1',
    name: 'Female 1',
    nameHe: 'קול נשי 1',
    gender: VoiceGender.female,
    family: VoiceFamily.blue,
    model: 'Blue 2',
    spec: _blue2(_blue2VoiceFemale1),
    clarity: 0.971,
    normalSpeed: 0.568,
  ),
  HebrewVoiceOption(
    id: 'blue2-male1',
    name: 'Male 1',
    nameHe: 'קול גברי 1',
    gender: VoiceGender.male,
    family: VoiceFamily.blue,
    model: 'Blue 2',
    spec: _blue2(_blue2VoiceMale1),
    clarity: 0.967,
    normalSpeed: 0.568,
  ),
  HebrewVoiceOption(
    id: 'blue3-roi',
    name: 'Roi',
    nameHe: 'רועי',
    gender: VoiceGender.male,
    family: VoiceFamily.blue,
    model: 'Blue V3',
    spec: _blueV3(_blueV3VoiceRoi),
    clarity: 0.964,
    normalSpeed: 0.842,
  ),
  HebrewVoiceOption(
    id: 'blue3-rotem',
    name: 'Rotem',
    nameHe: 'רותם',
    gender: VoiceGender.female,
    family: VoiceFamily.blue,
    model: 'Blue V3',
    spec: _blueV3(_blueV3VoiceRotem),
    clarity: 0.963,
    normalSpeed: 0.808,
  ),
  HebrewVoiceOption(
    id: 'blue25-female-6147',
    name: 'Reader 6147',
    nameHe: 'קוראת 6147',
    gender: VoiceGender.female,
    family: VoiceFamily.blue,
    model: 'Blue 2.5',
    spec: _blue25(_blue25VoiceLibriFemale6147),
    clarity: 0.963,
    normalSpeed: 0.545,
  ),
  HebrewVoiceOption(
    id: 'piper-medium-male',
    name: 'Male',
    nameHe: 'קול גברי',
    gender: VoiceGender.male,
    family: VoiceFamily.phonikudMedium,
    model: 'Piper',
    spec: PiperSpec(model: _phonikudMediumPiperMediumMale, config: _phonikudMediumModelConfig, input: PiperInput.soundsUnpadded),
    clarity: 0.962,
    normalSpeed: 0.589,
  ),
  HebrewVoiceOption(
    id: 'blue25-male-8088',
    name: 'Reader 8088',
    nameHe: 'קורא 8088',
    gender: VoiceGender.male,
    family: VoiceFamily.blue,
    model: 'Blue 2.5',
    spec: _blue25(_blue25VoiceLibriMale8088),
    clarity: 0.96,
    normalSpeed: 0.553,
  ),
  HebrewVoiceOption(
    id: 'phonikud-shaul',
    name: 'Shaul',
    nameHe: 'שאול',
    gender: VoiceGender.male,
    family: VoiceFamily.phonikud,
    model: 'Piper',
    spec: _phonikudVoice(_phonikudShaul),
    clarity: 0.957,
    normalSpeed: 0.393,
  ),
  HebrewVoiceOption(
    id: 'phonikud-demo',
    name: 'Phonikud demo',
    nameHe: 'קול ההדגמה של Phonikud',
    gender: VoiceGender.male,
    family: VoiceFamily.phonikud,
    model: 'Piper',
    spec: _phonikudVoice(_phonikudModel),
    clarity: 0.953,
    normalSpeed: 0.477,
  ),
  HebrewVoiceOption(
    id: 'pocket-liat',
    name: 'Liat',
    nameHe: 'ליאת',
    gender: VoiceGender.female,
    family: VoiceFamily.pocket,
    model: 'Pocket TTS',
    spec: PocketSpec(model: _pocketModel, assets: _pocketAssets, voice: 'liat'),
    clarity: 0.950,
    normalSpeed: 0.655,
  ),
  HebrewVoiceOption(
    id: 'pocket-alba',
    name: 'Alba',
    nameHe: 'אלבה',
    gender: VoiceGender.female,
    family: VoiceFamily.pocket,
    model: 'Pocket TTS',
    spec: PocketSpec(model: _pocketModel, assets: _pocketAssets, voice: 'alba'),
    clarity: 0.950,
    normalSpeed: 0.65,
  ),
  HebrewVoiceOption(
    id: 'pocket-omer',
    name: 'Omer',
    nameHe: 'עומר',
    gender: VoiceGender.male,
    family: VoiceFamily.pocket,
    model: 'Pocket TTS',
    spec: PocketSpec(model: _pocketModel, assets: _pocketAssets, voice: 'omer'),
    clarity: 0.949,
    normalSpeed: 0.646,
  ),
  HebrewVoiceOption(
    id: 'pocket-michael',
    name: 'Michael (Pocket)',
    nameHe: 'מיכאל (Pocket)',
    gender: VoiceGender.male,
    family: VoiceFamily.pocket,
    model: 'Pocket TTS',
    spec: PocketSpec(model: _pocketModel, assets: _pocketAssets, voice: 'michael'),
    clarity: 0.941,
    normalSpeed: 0.627,
  ),
  HebrewVoiceOption(
    id: 'pocket-anna',
    name: 'Anna',
    nameHe: 'אנה',
    gender: VoiceGender.female,
    family: VoiceFamily.pocket,
    model: 'Pocket TTS',
    spec: PocketSpec(model: _pocketModel, assets: _pocketAssets, voice: 'anna'),
    clarity: 0.938,
    normalSpeed: 0.675,
  ),
  // Phonikud's experiments: Shaul, trained other ways.
  HebrewVoiceOption(
    id: 'phonikud-shaul-whisper',
    name: 'Shaul, Whisper phonemes',
    nameHe: 'שאול, הגיית Whisper',
    gender: VoiceGender.male,
    family: VoiceFamily.phonikud,
    model: 'Piper',
    spec: _phonikudVoice(_phonikudShaulWhisperHebIpa1),
    clarity: 0.933,
    normalSpeed: 0.348,
    group: VoiceGroup.experimental,
  ),
  HebrewVoiceOption(
    id: 'phonikud-exp-hand',
    name: 'Shaul, hand phonemes',
    nameHe: 'שאול, הגייה ידנית',
    gender: VoiceGender.male,
    family: VoiceFamily.phonikud,
    model: 'Piper',
    spec: _phonikudVoice(_phonikudExpExportHand),
    clarity: 0.91,
    normalSpeed: 0.466,
    group: VoiceGroup.experimental,
  ),
  HebrewVoiceOption(
    id: 'phonikud-exp-plain',
    name: 'Shaul, Phonikud phonemes',
    nameHe: 'שאול, הגיית Phonikud',
    gender: VoiceGender.male,
    family: VoiceFamily.phonikud,
    model: 'Piper',
    spec: _phonikudVoice(_phonikudExpExportPhonikudNonEnhanced),
    clarity: 0.872,
    normalSpeed: 0.418,
    group: VoiceGroup.experimental,
  ),
  HebrewVoiceOption(
    id: 'phonikud-exp-enhanced',
    name: 'Shaul, enhanced Phonikud phonemes',
    nameHe: 'שאול, הגיית Phonikud המשופרת',
    gender: VoiceGender.male,
    family: VoiceFamily.phonikud,
    model: 'Piper',
    spec: _phonikudVoice(_phonikudExpExportPhonikudEnhanced),
    clarity: 0.854,
    normalSpeed: 0.425,
    group: VoiceGroup.experimental,
  ),
  HebrewVoiceOption(
    id: 'phonikud-exp-pointed',
    name: 'Shaul, reading the pointed letters',
    nameHe: 'שאול, קורא את האותיות המנוקדות',
    gender: VoiceGender.male,
    family: VoiceFamily.phonikud,
    model: 'Piper',
    spec: _phonikudVoice(_phonikudExpExportVocalized, letters: _phonikudExpMapVocalized, input: PiperInput.pointedLetters),
    clarity: 0.704,
    normalSpeed: 0.347,
    group: VoiceGroup.experimental,
  ),
  HebrewVoiceOption(
    id: 'phonikud-exp-bare',
    name: 'Shaul, reading the bare letters',
    nameHe: 'שאול, קורא אותיות ללא ניקוד',
    gender: VoiceGender.male,
    family: VoiceFamily.phonikud,
    model: 'Piper',
    spec: _phonikudVoice(_phonikudExpExportNonVocalized, letters: _phonikudExpMapNonVocalized, input: PiperInput.bareLetters),
    clarity: 0.693,
    normalSpeed: 0.429,
    group: VoiceGroup.experimental,
  ),
]);

/// The voice whose id is [id], or null if none is.
HebrewVoiceOption? hebrewVoiceById(String? id) => hebrewVoices.where((v) => v.id == id).firstOrNull;
