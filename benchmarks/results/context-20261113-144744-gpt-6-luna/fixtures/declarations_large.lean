import Tests.ContextBench
import Tests.ContextSupport
set_option maxHeartbeats 0
set_option llmlean.attempts 1

namespace ContextBench
def pushTwice {α : Type} (xs : List α) (x : α) : List α :=
  (xs ++ [x]) ++ [x]
theorem pushTwice_eq {α : Type} (xs : List α) (x : α) :
    pushTwice xs x = (xs ++ [x]) ++ [x] := by rfl
theorem distractor_0 (n : Nat) : n = n := by
  rfl
theorem distractor_1 (n : Nat) : n = n := by
  rfl
theorem distractor_2 (n : Nat) : n = n := by
  rfl
theorem distractor_3 (n : Nat) : n = n := by
  rfl
theorem distractor_4 (n : Nat) : n = n := by
  rfl
theorem distractor_5 (n : Nat) : n = n := by
  rfl
theorem distractor_6 (n : Nat) : n = n := by
  rfl
theorem distractor_7 (n : Nat) : n = n := by
  rfl
theorem distractor_8 (n : Nat) : n = n := by
  rfl
theorem distractor_9 (n : Nat) : n = n := by
  rfl
theorem distractor_10 (n : Nat) : n = n := by
  rfl
theorem distractor_11 (n : Nat) : n = n := by
  rfl
theorem distractor_12 (n : Nat) : n = n := by
  rfl
theorem distractor_13 (n : Nat) : n = n := by
  rfl
theorem distractor_14 (n : Nat) : n = n := by
  rfl
theorem distractor_15 (n : Nat) : n = n := by
  rfl
theorem distractor_16 (n : Nat) : n = n := by
  rfl
theorem distractor_17 (n : Nat) : n = n := by
  rfl
theorem distractor_18 (n : Nat) : n = n := by
  rfl
theorem distractor_19 (n : Nat) : n = n := by
  rfl
theorem distractor_20 (n : Nat) : n = n := by
  rfl
theorem distractor_21 (n : Nat) : n = n := by
  rfl
theorem distractor_22 (n : Nat) : n = n := by
  rfl
theorem distractor_23 (n : Nat) : n = n := by
  rfl
theorem distractor_24 (n : Nat) : n = n := by
  rfl
theorem distractor_25 (n : Nat) : n = n := by
  rfl
theorem distractor_26 (n : Nat) : n = n := by
  rfl
theorem distractor_27 (n : Nat) : n = n := by
  rfl
theorem distractor_28 (n : Nat) : n = n := by
  rfl
theorem distractor_29 (n : Nat) : n = n := by
  rfl
theorem distractor_30 (n : Nat) : n = n := by
  rfl
theorem distractor_31 (n : Nat) : n = n := by
  rfl
theorem distractor_32 (n : Nat) : n = n := by
  rfl
theorem distractor_33 (n : Nat) : n = n := by
  rfl
theorem distractor_34 (n : Nat) : n = n := by
  rfl
theorem distractor_35 (n : Nat) : n = n := by
  rfl
theorem distractor_36 (n : Nat) : n = n := by
  rfl
theorem distractor_37 (n : Nat) : n = n := by
  rfl
theorem distractor_38 (n : Nat) : n = n := by
  rfl
theorem distractor_39 (n : Nat) : n = n := by
  rfl
theorem distractor_40 (n : Nat) : n = n := by
  rfl
theorem distractor_41 (n : Nat) : n = n := by
  rfl
theorem distractor_42 (n : Nat) : n = n := by
  rfl
theorem distractor_43 (n : Nat) : n = n := by
  rfl
theorem distractor_44 (n : Nat) : n = n := by
  rfl
theorem distractor_45 (n : Nat) : n = n := by
  rfl
theorem distractor_46 (n : Nat) : n = n := by
  rfl
theorem distractor_47 (n : Nat) : n = n := by
  rfl
theorem distractor_48 (n : Nat) : n = n := by
  rfl
theorem distractor_49 (n : Nat) : n = n := by
  rfl
theorem distractor_50 (n : Nat) : n = n := by
  rfl
theorem distractor_51 (n : Nat) : n = n := by
  rfl
theorem distractor_52 (n : Nat) : n = n := by
  rfl
theorem distractor_53 (n : Nat) : n = n := by
  rfl
theorem distractor_54 (n : Nat) : n = n := by
  rfl
theorem distractor_55 (n : Nat) : n = n := by
  rfl
theorem distractor_56 (n : Nat) : n = n := by
  rfl
theorem distractor_57 (n : Nat) : n = n := by
  rfl
theorem distractor_58 (n : Nat) : n = n := by
  rfl
theorem distractor_59 (n : Nat) : n = n := by
  rfl
theorem distractor_60 (n : Nat) : n = n := by
  rfl
theorem distractor_61 (n : Nat) : n = n := by
  rfl
theorem distractor_62 (n : Nat) : n = n := by
  rfl
theorem distractor_63 (n : Nat) : n = n := by
  rfl
theorem distractor_64 (n : Nat) : n = n := by
  rfl
theorem distractor_65 (n : Nat) : n = n := by
  rfl
theorem distractor_66 (n : Nat) : n = n := by
  rfl
theorem distractor_67 (n : Nat) : n = n := by
  rfl
theorem distractor_68 (n : Nat) : n = n := by
  rfl
theorem distractor_69 (n : Nat) : n = n := by
  rfl
theorem distractor_70 (n : Nat) : n = n := by
  rfl
theorem distractor_71 (n : Nat) : n = n := by
  rfl
theorem distractor_72 (n : Nat) : n = n := by
  rfl
theorem distractor_73 (n : Nat) : n = n := by
  rfl
theorem distractor_74 (n : Nat) : n = n := by
  rfl
theorem distractor_75 (n : Nat) : n = n := by
  rfl
theorem distractor_76 (n : Nat) : n = n := by
  rfl
theorem distractor_77 (n : Nat) : n = n := by
  rfl
theorem distractor_78 (n : Nat) : n = n := by
  rfl
theorem distractor_79 (n : Nat) : n = n := by
  rfl
theorem distractor_80 (n : Nat) : n = n := by
  rfl
theorem distractor_81 (n : Nat) : n = n := by
  rfl
theorem distractor_82 (n : Nat) : n = n := by
  rfl
theorem distractor_83 (n : Nat) : n = n := by
  rfl
theorem distractor_84 (n : Nat) : n = n := by
  rfl
theorem distractor_85 (n : Nat) : n = n := by
  rfl
theorem distractor_86 (n : Nat) : n = n := by
  rfl
theorem distractor_87 (n : Nat) : n = n := by
  rfl
theorem distractor_88 (n : Nat) : n = n := by
  rfl
theorem distractor_89 (n : Nat) : n = n := by
  rfl
theorem distractor_90 (n : Nat) : n = n := by
  rfl
theorem distractor_91 (n : Nat) : n = n := by
  rfl
theorem distractor_92 (n : Nat) : n = n := by
  rfl
theorem distractor_93 (n : Nat) : n = n := by
  rfl
theorem distractor_94 (n : Nat) : n = n := by
  rfl
theorem distractor_95 (n : Nat) : n = n := by
  rfl
theorem distractor_96 (n : Nat) : n = n := by
  rfl
theorem distractor_97 (n : Nat) : n = n := by
  rfl
theorem distractor_98 (n : Nat) : n = n := by
  rfl
theorem distractor_99 (n : Nat) : n = n := by
  rfl
theorem distractor_100 (n : Nat) : n = n := by
  rfl
theorem distractor_101 (n : Nat) : n = n := by
  rfl
theorem distractor_102 (n : Nat) : n = n := by
  rfl
theorem distractor_103 (n : Nat) : n = n := by
  rfl
theorem distractor_104 (n : Nat) : n = n := by
  rfl
theorem distractor_105 (n : Nat) : n = n := by
  rfl
theorem distractor_106 (n : Nat) : n = n := by
  rfl
theorem distractor_107 (n : Nat) : n = n := by
  rfl
theorem distractor_108 (n : Nat) : n = n := by
  rfl
theorem distractor_109 (n : Nat) : n = n := by
  rfl
theorem distractor_110 (n : Nat) : n = n := by
  rfl
theorem distractor_111 (n : Nat) : n = n := by
  rfl
theorem distractor_112 (n : Nat) : n = n := by
  rfl
theorem distractor_113 (n : Nat) : n = n := by
  rfl
theorem distractor_114 (n : Nat) : n = n := by
  rfl
theorem distractor_115 (n : Nat) : n = n := by
  rfl
theorem distractor_116 (n : Nat) : n = n := by
  rfl
theorem distractor_117 (n : Nat) : n = n := by
  rfl
theorem distractor_118 (n : Nat) : n = n := by
  rfl
theorem distractor_119 (n : Nat) : n = n := by
  rfl
theorem distractor_120 (n : Nat) : n = n := by
  rfl
theorem distractor_121 (n : Nat) : n = n := by
  rfl
theorem distractor_122 (n : Nat) : n = n := by
  rfl
theorem distractor_123 (n : Nat) : n = n := by
  rfl
theorem distractor_124 (n : Nat) : n = n := by
  rfl
theorem distractor_125 (n : Nat) : n = n := by
  rfl
theorem distractor_126 (n : Nat) : n = n := by
  rfl
theorem distractor_127 (n : Nat) : n = n := by
  rfl
theorem distractor_128 (n : Nat) : n = n := by
  rfl
theorem distractor_129 (n : Nat) : n = n := by
  rfl
theorem distractor_130 (n : Nat) : n = n := by
  rfl
theorem distractor_131 (n : Nat) : n = n := by
  rfl
theorem distractor_132 (n : Nat) : n = n := by
  rfl
theorem distractor_133 (n : Nat) : n = n := by
  rfl
theorem distractor_134 (n : Nat) : n = n := by
  rfl
theorem distractor_135 (n : Nat) : n = n := by
  rfl
theorem distractor_136 (n : Nat) : n = n := by
  rfl
theorem distractor_137 (n : Nat) : n = n := by
  rfl
theorem distractor_138 (n : Nat) : n = n := by
  rfl
theorem distractor_139 (n : Nat) : n = n := by
  rfl
theorem distractor_140 (n : Nat) : n = n := by
  rfl
theorem distractor_141 (n : Nat) : n = n := by
  rfl
theorem distractor_142 (n : Nat) : n = n := by
  rfl
theorem distractor_143 (n : Nat) : n = n := by
  rfl
theorem distractor_144 (n : Nat) : n = n := by
  rfl
theorem distractor_145 (n : Nat) : n = n := by
  rfl
theorem distractor_146 (n : Nat) : n = n := by
  rfl
theorem distractor_147 (n : Nat) : n = n := by
  rfl
theorem distractor_148 (n : Nat) : n = n := by
  rfl
theorem distractor_149 (n : Nat) : n = n := by
  rfl
theorem distractor_150 (n : Nat) : n = n := by
  rfl
theorem distractor_151 (n : Nat) : n = n := by
  rfl
theorem distractor_152 (n : Nat) : n = n := by
  rfl
theorem distractor_153 (n : Nat) : n = n := by
  rfl
theorem distractor_154 (n : Nat) : n = n := by
  rfl
theorem distractor_155 (n : Nat) : n = n := by
  rfl
theorem distractor_156 (n : Nat) : n = n := by
  rfl
theorem distractor_157 (n : Nat) : n = n := by
  rfl
theorem distractor_158 (n : Nat) : n = n := by
  rfl
theorem distractor_159 (n : Nat) : n = n := by
  rfl
theorem distractor_160 (n : Nat) : n = n := by
  rfl
theorem distractor_161 (n : Nat) : n = n := by
  rfl
theorem distractor_162 (n : Nat) : n = n := by
  rfl
theorem distractor_163 (n : Nat) : n = n := by
  rfl
theorem distractor_164 (n : Nat) : n = n := by
  rfl
theorem distractor_165 (n : Nat) : n = n := by
  rfl
theorem distractor_166 (n : Nat) : n = n := by
  rfl
theorem distractor_167 (n : Nat) : n = n := by
  rfl
theorem distractor_168 (n : Nat) : n = n := by
  rfl
theorem distractor_169 (n : Nat) : n = n := by
  rfl
theorem distractor_170 (n : Nat) : n = n := by
  rfl
theorem distractor_171 (n : Nat) : n = n := by
  rfl
theorem distractor_172 (n : Nat) : n = n := by
  rfl
theorem distractor_173 (n : Nat) : n = n := by
  rfl
theorem distractor_174 (n : Nat) : n = n := by
  rfl
theorem distractor_175 (n : Nat) : n = n := by
  rfl
theorem distractor_176 (n : Nat) : n = n := by
  rfl
theorem distractor_177 (n : Nat) : n = n := by
  rfl
theorem distractor_178 (n : Nat) : n = n := by
  rfl
theorem distractor_179 (n : Nat) : n = n := by
  rfl
theorem distractor_180 (n : Nat) : n = n := by
  rfl
theorem distractor_181 (n : Nat) : n = n := by
  rfl
theorem distractor_182 (n : Nat) : n = n := by
  rfl
theorem distractor_183 (n : Nat) : n = n := by
  rfl
theorem distractor_184 (n : Nat) : n = n := by
  rfl
theorem distractor_185 (n : Nat) : n = n := by
  rfl
theorem distractor_186 (n : Nat) : n = n := by
  rfl
theorem distractor_187 (n : Nat) : n = n := by
  rfl
theorem distractor_188 (n : Nat) : n = n := by
  rfl
theorem distractor_189 (n : Nat) : n = n := by
  rfl
theorem distractor_190 (n : Nat) : n = n := by
  rfl
theorem distractor_191 (n : Nat) : n = n := by
  rfl
theorem distractor_192 (n : Nat) : n = n := by
  rfl
theorem distractor_193 (n : Nat) : n = n := by
  rfl
theorem distractor_194 (n : Nat) : n = n := by
  rfl
theorem distractor_195 (n : Nat) : n = n := by
  rfl
theorem distractor_196 (n : Nat) : n = n := by
  rfl
theorem distractor_197 (n : Nat) : n = n := by
  rfl
theorem distractor_198 (n : Nat) : n = n := by
  rfl
theorem distractor_199 (n : Nat) : n = n := by
  rfl
theorem distractor_200 (n : Nat) : n = n := by
  rfl
theorem distractor_201 (n : Nat) : n = n := by
  rfl
theorem distractor_202 (n : Nat) : n = n := by
  rfl
theorem distractor_203 (n : Nat) : n = n := by
  rfl
theorem distractor_204 (n : Nat) : n = n := by
  rfl
theorem distractor_205 (n : Nat) : n = n := by
  rfl
theorem distractor_206 (n : Nat) : n = n := by
  rfl
theorem distractor_207 (n : Nat) : n = n := by
  rfl
theorem distractor_208 (n : Nat) : n = n := by
  rfl
theorem distractor_209 (n : Nat) : n = n := by
  rfl
theorem distractor_210 (n : Nat) : n = n := by
  rfl
theorem distractor_211 (n : Nat) : n = n := by
  rfl
theorem distractor_212 (n : Nat) : n = n := by
  rfl
theorem distractor_213 (n : Nat) : n = n := by
  rfl
theorem distractor_214 (n : Nat) : n = n := by
  rfl
theorem distractor_215 (n : Nat) : n = n := by
  rfl
theorem distractor_216 (n : Nat) : n = n := by
  rfl
theorem distractor_217 (n : Nat) : n = n := by
  rfl
theorem distractor_218 (n : Nat) : n = n := by
  rfl
theorem distractor_219 (n : Nat) : n = n := by
  rfl
theorem distractor_220 (n : Nat) : n = n := by
  rfl
theorem distractor_221 (n : Nat) : n = n := by
  rfl
theorem distractor_222 (n : Nat) : n = n := by
  rfl
theorem distractor_223 (n : Nat) : n = n := by
  rfl
theorem distractor_224 (n : Nat) : n = n := by
  rfl
theorem distractor_225 (n : Nat) : n = n := by
  rfl
theorem distractor_226 (n : Nat) : n = n := by
  rfl
theorem distractor_227 (n : Nat) : n = n := by
  rfl
theorem distractor_228 (n : Nat) : n = n := by
  rfl
theorem distractor_229 (n : Nat) : n = n := by
  rfl
theorem distractor_230 (n : Nat) : n = n := by
  rfl
theorem distractor_231 (n : Nat) : n = n := by
  rfl
theorem distractor_232 (n : Nat) : n = n := by
  rfl
theorem distractor_233 (n : Nat) : n = n := by
  rfl
theorem distractor_234 (n : Nat) : n = n := by
  rfl
theorem distractor_235 (n : Nat) : n = n := by
  rfl
theorem distractor_236 (n : Nat) : n = n := by
  rfl
theorem distractor_237 (n : Nat) : n = n := by
  rfl
theorem distractor_238 (n : Nat) : n = n := by
  rfl
theorem distractor_239 (n : Nat) : n = n := by
  rfl
theorem distractor_240 (n : Nat) : n = n := by
  rfl
theorem distractor_241 (n : Nat) : n = n := by
  rfl
theorem distractor_242 (n : Nat) : n = n := by
  rfl
theorem distractor_243 (n : Nat) : n = n := by
  rfl
theorem distractor_244 (n : Nat) : n = n := by
  rfl
theorem distractor_245 (n : Nat) : n = n := by
  rfl
theorem distractor_246 (n : Nat) : n = n := by
  rfl
theorem distractor_247 (n : Nat) : n = n := by
  rfl
theorem distractor_248 (n : Nat) : n = n := by
  rfl
theorem distractor_249 (n : Nat) : n = n := by
  rfl
theorem distractor_250 (n : Nat) : n = n := by
  rfl
theorem distractor_251 (n : Nat) : n = n := by
  rfl
theorem distractor_252 (n : Nat) : n = n := by
  rfl
theorem distractor_253 (n : Nat) : n = n := by
  rfl
theorem distractor_254 (n : Nat) : n = n := by
  rfl
theorem distractor_255 (n : Nat) : n = n := by
  rfl
theorem distractor_256 (n : Nat) : n = n := by
  rfl
theorem distractor_257 (n : Nat) : n = n := by
  rfl
theorem distractor_258 (n : Nat) : n = n := by
  rfl
theorem distractor_259 (n : Nat) : n = n := by
  rfl
theorem distractor_260 (n : Nat) : n = n := by
  rfl
theorem distractor_261 (n : Nat) : n = n := by
  rfl
theorem distractor_262 (n : Nat) : n = n := by
  rfl
theorem distractor_263 (n : Nat) : n = n := by
  rfl
theorem distractor_264 (n : Nat) : n = n := by
  rfl
theorem distractor_265 (n : Nat) : n = n := by
  rfl
theorem distractor_266 (n : Nat) : n = n := by
  rfl
theorem distractor_267 (n : Nat) : n = n := by
  rfl
theorem distractor_268 (n : Nat) : n = n := by
  rfl
theorem distractor_269 (n : Nat) : n = n := by
  rfl
theorem distractor_270 (n : Nat) : n = n := by
  rfl
theorem distractor_271 (n : Nat) : n = n := by
  rfl
theorem distractor_272 (n : Nat) : n = n := by
  rfl
theorem distractor_273 (n : Nat) : n = n := by
  rfl
theorem distractor_274 (n : Nat) : n = n := by
  rfl
theorem distractor_275 (n : Nat) : n = n := by
  rfl
theorem distractor_276 (n : Nat) : n = n := by
  rfl
theorem distractor_277 (n : Nat) : n = n := by
  rfl
theorem distractor_278 (n : Nat) : n = n := by
  rfl
theorem distractor_279 (n : Nat) : n = n := by
  rfl
theorem distractor_280 (n : Nat) : n = n := by
  rfl
theorem distractor_281 (n : Nat) : n = n := by
  rfl
theorem distractor_282 (n : Nat) : n = n := by
  rfl
theorem distractor_283 (n : Nat) : n = n := by
  rfl
theorem distractor_284 (n : Nat) : n = n := by
  rfl
theorem distractor_285 (n : Nat) : n = n := by
  rfl
theorem distractor_286 (n : Nat) : n = n := by
  rfl
theorem distractor_287 (n : Nat) : n = n := by
  rfl
theorem distractor_288 (n : Nat) : n = n := by
  rfl
theorem distractor_289 (n : Nat) : n = n := by
  rfl
theorem distractor_290 (n : Nat) : n = n := by
  rfl
theorem distractor_291 (n : Nat) : n = n := by
  rfl
theorem distractor_292 (n : Nat) : n = n := by
  rfl
theorem distractor_293 (n : Nat) : n = n := by
  rfl
theorem distractor_294 (n : Nat) : n = n := by
  rfl
theorem distractor_295 (n : Nat) : n = n := by
  rfl
theorem distractor_296 (n : Nat) : n = n := by
  rfl
theorem distractor_297 (n : Nat) : n = n := by
  rfl
theorem distractor_298 (n : Nat) : n = n := by
  rfl
theorem distractor_299 (n : Nat) : n = n := by
  rfl
theorem distractor_300 (n : Nat) : n = n := by
  rfl
theorem distractor_301 (n : Nat) : n = n := by
  rfl
theorem distractor_302 (n : Nat) : n = n := by
  rfl
theorem distractor_303 (n : Nat) : n = n := by
  rfl
theorem distractor_304 (n : Nat) : n = n := by
  rfl
theorem distractor_305 (n : Nat) : n = n := by
  rfl
theorem distractor_306 (n : Nat) : n = n := by
  rfl
theorem distractor_307 (n : Nat) : n = n := by
  rfl
theorem distractor_308 (n : Nat) : n = n := by
  rfl
theorem distractor_309 (n : Nat) : n = n := by
  rfl
theorem distractor_310 (n : Nat) : n = n := by
  rfl
theorem distractor_311 (n : Nat) : n = n := by
  rfl
theorem distractor_312 (n : Nat) : n = n := by
  rfl
theorem distractor_313 (n : Nat) : n = n := by
  rfl
theorem distractor_314 (n : Nat) : n = n := by
  rfl
theorem distractor_315 (n : Nat) : n = n := by
  rfl
theorem distractor_316 (n : Nat) : n = n := by
  rfl
theorem distractor_317 (n : Nat) : n = n := by
  rfl
theorem distractor_318 (n : Nat) : n = n := by
  rfl
theorem distractor_319 (n : Nat) : n = n := by
  rfl
theorem distractor_320 (n : Nat) : n = n := by
  rfl
theorem distractor_321 (n : Nat) : n = n := by
  rfl
theorem distractor_322 (n : Nat) : n = n := by
  rfl
theorem distractor_323 (n : Nat) : n = n := by
  rfl
theorem distractor_324 (n : Nat) : n = n := by
  rfl
theorem distractor_325 (n : Nat) : n = n := by
  rfl
theorem distractor_326 (n : Nat) : n = n := by
  rfl
theorem distractor_327 (n : Nat) : n = n := by
  rfl
theorem distractor_328 (n : Nat) : n = n := by
  rfl
theorem distractor_329 (n : Nat) : n = n := by
  rfl
theorem distractor_330 (n : Nat) : n = n := by
  rfl
theorem distractor_331 (n : Nat) : n = n := by
  rfl
theorem distractor_332 (n : Nat) : n = n := by
  rfl
theorem distractor_333 (n : Nat) : n = n := by
  rfl
theorem distractor_334 (n : Nat) : n = n := by
  rfl
theorem distractor_335 (n : Nat) : n = n := by
  rfl
theorem distractor_336 (n : Nat) : n = n := by
  rfl
theorem distractor_337 (n : Nat) : n = n := by
  rfl
theorem distractor_338 (n : Nat) : n = n := by
  rfl
theorem distractor_339 (n : Nat) : n = n := by
  rfl
theorem distractor_340 (n : Nat) : n = n := by
  rfl
theorem distractor_341 (n : Nat) : n = n := by
  rfl
theorem distractor_342 (n : Nat) : n = n := by
  rfl
theorem distractor_343 (n : Nat) : n = n := by
  rfl
theorem distractor_344 (n : Nat) : n = n := by
  rfl
theorem distractor_345 (n : Nat) : n = n := by
  rfl
theorem distractor_346 (n : Nat) : n = n := by
  rfl
theorem distractor_347 (n : Nat) : n = n := by
  rfl
theorem distractor_348 (n : Nat) : n = n := by
  rfl
theorem distractor_349 (n : Nat) : n = n := by
  rfl
theorem distractor_350 (n : Nat) : n = n := by
  rfl
theorem distractor_351 (n : Nat) : n = n := by
  rfl
theorem distractor_352 (n : Nat) : n = n := by
  rfl
theorem distractor_353 (n : Nat) : n = n := by
  rfl
theorem distractor_354 (n : Nat) : n = n := by
  rfl
theorem distractor_355 (n : Nat) : n = n := by
  rfl
theorem distractor_356 (n : Nat) : n = n := by
  rfl
theorem distractor_357 (n : Nat) : n = n := by
  rfl
theorem distractor_358 (n : Nat) : n = n := by
  rfl
theorem distractor_359 (n : Nat) : n = n := by
  rfl
theorem distractor_360 (n : Nat) : n = n := by
  rfl
theorem distractor_361 (n : Nat) : n = n := by
  rfl
theorem distractor_362 (n : Nat) : n = n := by
  rfl
theorem distractor_363 (n : Nat) : n = n := by
  rfl
theorem distractor_364 (n : Nat) : n = n := by
  rfl
theorem distractor_365 (n : Nat) : n = n := by
  rfl
theorem distractor_366 (n : Nat) : n = n := by
  rfl
theorem distractor_367 (n : Nat) : n = n := by
  rfl
theorem distractor_368 (n : Nat) : n = n := by
  rfl
theorem distractor_369 (n : Nat) : n = n := by
  rfl
theorem distractor_370 (n : Nat) : n = n := by
  rfl
theorem distractor_371 (n : Nat) : n = n := by
  rfl
theorem distractor_372 (n : Nat) : n = n := by
  rfl
theorem distractor_373 (n : Nat) : n = n := by
  rfl
theorem distractor_374 (n : Nat) : n = n := by
  rfl
theorem distractor_375 (n : Nat) : n = n := by
  rfl
theorem distractor_376 (n : Nat) : n = n := by
  rfl
theorem distractor_377 (n : Nat) : n = n := by
  rfl
theorem distractor_378 (n : Nat) : n = n := by
  rfl
theorem distractor_379 (n : Nat) : n = n := by
  rfl
theorem distractor_380 (n : Nat) : n = n := by
  rfl
theorem distractor_381 (n : Nat) : n = n := by
  rfl
theorem distractor_382 (n : Nat) : n = n := by
  rfl
theorem distractor_383 (n : Nat) : n = n := by
  rfl
theorem distractor_384 (n : Nat) : n = n := by
  rfl
theorem distractor_385 (n : Nat) : n = n := by
  rfl
theorem distractor_386 (n : Nat) : n = n := by
  rfl
theorem distractor_387 (n : Nat) : n = n := by
  rfl
theorem distractor_388 (n : Nat) : n = n := by
  rfl
theorem distractor_389 (n : Nat) : n = n := by
  rfl
theorem distractor_390 (n : Nat) : n = n := by
  rfl
theorem distractor_391 (n : Nat) : n = n := by
  rfl
theorem distractor_392 (n : Nat) : n = n := by
  rfl
theorem distractor_393 (n : Nat) : n = n := by
  rfl
theorem distractor_394 (n : Nat) : n = n := by
  rfl
theorem distractor_395 (n : Nat) : n = n := by
  rfl
theorem distractor_396 (n : Nat) : n = n := by
  rfl
theorem distractor_397 (n : Nat) : n = n := by
  rfl
theorem distractor_398 (n : Nat) : n = n := by
  rfl
theorem distractor_399 (n : Nat) : n = n := by
  rfl
theorem distractor_400 (n : Nat) : n = n := by
  rfl
theorem distractor_401 (n : Nat) : n = n := by
  rfl
theorem distractor_402 (n : Nat) : n = n := by
  rfl
theorem distractor_403 (n : Nat) : n = n := by
  rfl
theorem distractor_404 (n : Nat) : n = n := by
  rfl
theorem distractor_405 (n : Nat) : n = n := by
  rfl
theorem distractor_406 (n : Nat) : n = n := by
  rfl
theorem distractor_407 (n : Nat) : n = n := by
  rfl
theorem distractor_408 (n : Nat) : n = n := by
  rfl
theorem distractor_409 (n : Nat) : n = n := by
  rfl
theorem distractor_410 (n : Nat) : n = n := by
  rfl
theorem distractor_411 (n : Nat) : n = n := by
  rfl
theorem distractor_412 (n : Nat) : n = n := by
  rfl
theorem distractor_413 (n : Nat) : n = n := by
  rfl
theorem distractor_414 (n : Nat) : n = n := by
  rfl
theorem distractor_415 (n : Nat) : n = n := by
  rfl
theorem distractor_416 (n : Nat) : n = n := by
  rfl
theorem distractor_417 (n : Nat) : n = n := by
  rfl
theorem distractor_418 (n : Nat) : n = n := by
  rfl
theorem distractor_419 (n : Nat) : n = n := by
  rfl
theorem distractor_420 (n : Nat) : n = n := by
  rfl
theorem distractor_421 (n : Nat) : n = n := by
  rfl
theorem distractor_422 (n : Nat) : n = n := by
  rfl
theorem distractor_423 (n : Nat) : n = n := by
  rfl
theorem distractor_424 (n : Nat) : n = n := by
  rfl
theorem distractor_425 (n : Nat) : n = n := by
  rfl
theorem distractor_426 (n : Nat) : n = n := by
  rfl
theorem distractor_427 (n : Nat) : n = n := by
  rfl
theorem distractor_428 (n : Nat) : n = n := by
  rfl
theorem distractor_429 (n : Nat) : n = n := by
  rfl
theorem distractor_430 (n : Nat) : n = n := by
  rfl
theorem distractor_431 (n : Nat) : n = n := by
  rfl
theorem distractor_432 (n : Nat) : n = n := by
  rfl
theorem distractor_433 (n : Nat) : n = n := by
  rfl
theorem distractor_434 (n : Nat) : n = n := by
  rfl
theorem distractor_435 (n : Nat) : n = n := by
  rfl
theorem distractor_436 (n : Nat) : n = n := by
  rfl
theorem distractor_437 (n : Nat) : n = n := by
  rfl
theorem distractor_438 (n : Nat) : n = n := by
  rfl
theorem distractor_439 (n : Nat) : n = n := by
  rfl
theorem distractor_440 (n : Nat) : n = n := by
  rfl
theorem distractor_441 (n : Nat) : n = n := by
  rfl
theorem distractor_442 (n : Nat) : n = n := by
  rfl
theorem distractor_443 (n : Nat) : n = n := by
  rfl
theorem distractor_444 (n : Nat) : n = n := by
  rfl
theorem distractor_445 (n : Nat) : n = n := by
  rfl
theorem distractor_446 (n : Nat) : n = n := by
  rfl
theorem distractor_447 (n : Nat) : n = n := by
  rfl
theorem distractor_448 (n : Nat) : n = n := by
  rfl
theorem distractor_449 (n : Nat) : n = n := by
  rfl
theorem distractor_450 (n : Nat) : n = n := by
  rfl
theorem distractor_451 (n : Nat) : n = n := by
  rfl
theorem distractor_452 (n : Nat) : n = n := by
  rfl
theorem distractor_453 (n : Nat) : n = n := by
  rfl
theorem distractor_454 (n : Nat) : n = n := by
  rfl
theorem distractor_455 (n : Nat) : n = n := by
  rfl
theorem distractor_456 (n : Nat) : n = n := by
  rfl
theorem distractor_457 (n : Nat) : n = n := by
  rfl
theorem distractor_458 (n : Nat) : n = n := by
  rfl
theorem distractor_459 (n : Nat) : n = n := by
  rfl
theorem distractor_460 (n : Nat) : n = n := by
  rfl
theorem distractor_461 (n : Nat) : n = n := by
  rfl
theorem distractor_462 (n : Nat) : n = n := by
  rfl
theorem distractor_463 (n : Nat) : n = n := by
  rfl
theorem distractor_464 (n : Nat) : n = n := by
  rfl
theorem distractor_465 (n : Nat) : n = n := by
  rfl
theorem distractor_466 (n : Nat) : n = n := by
  rfl
theorem distractor_467 (n : Nat) : n = n := by
  rfl
theorem distractor_468 (n : Nat) : n = n := by
  rfl
theorem distractor_469 (n : Nat) : n = n := by
  rfl
theorem distractor_470 (n : Nat) : n = n := by
  rfl
theorem distractor_471 (n : Nat) : n = n := by
  rfl
theorem distractor_472 (n : Nat) : n = n := by
  rfl
theorem distractor_473 (n : Nat) : n = n := by
  rfl
theorem distractor_474 (n : Nat) : n = n := by
  rfl
theorem distractor_475 (n : Nat) : n = n := by
  rfl
theorem distractor_476 (n : Nat) : n = n := by
  rfl
theorem distractor_477 (n : Nat) : n = n := by
  rfl
theorem distractor_478 (n : Nat) : n = n := by
  rfl
theorem distractor_479 (n : Nat) : n = n := by
  rfl
theorem distractor_480 (n : Nat) : n = n := by
  rfl
theorem distractor_481 (n : Nat) : n = n := by
  rfl
theorem distractor_482 (n : Nat) : n = n := by
  rfl
theorem distractor_483 (n : Nat) : n = n := by
  rfl
theorem distractor_484 (n : Nat) : n = n := by
  rfl
theorem distractor_485 (n : Nat) : n = n := by
  rfl
theorem distractor_486 (n : Nat) : n = n := by
  rfl
theorem distractor_487 (n : Nat) : n = n := by
  rfl
theorem distractor_488 (n : Nat) : n = n := by
  rfl
theorem distractor_489 (n : Nat) : n = n := by
  rfl
theorem distractor_490 (n : Nat) : n = n := by
  rfl
theorem distractor_491 (n : Nat) : n = n := by
  rfl
theorem distractor_492 (n : Nat) : n = n := by
  rfl
theorem distractor_493 (n : Nat) : n = n := by
  rfl
theorem distractor_494 (n : Nat) : n = n := by
  rfl
theorem distractor_495 (n : Nat) : n = n := by
  rfl
theorem distractor_496 (n : Nat) : n = n := by
  rfl
theorem distractor_497 (n : Nat) : n = n := by
  rfl
theorem distractor_498 (n : Nat) : n = n := by
  rfl
theorem distractor_499 (n : Nat) : n = n := by
  rfl

open ContextExample.ListTools
local notation "push₂" => pushTwice
example {α : Type} (xs : List α) (x : α) (n : Nat) (h : xs.length = n) :
    (push₂ xs x).length = n + 2 := by
  have hlen : xs.length + 2 = n + 2 := congrArg (fun k => k + 2) h
  context_benchmark "declarations_large" 0 false
  simpa only [pushTwice_eq, length_append_one] using hlen
end ContextBench
