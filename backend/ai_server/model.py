import torch
import torch.nn as nn

# --- 1. ส่วนประกอบ: ConvLSTM Cell ---
class ConvLSTMCell(nn.Module):
    def __init__(self, input_dim, hidden_dim, kernel_size, bias):
        super(ConvLSTMCell, self).__init__()
        self.input_dim = input_dim
        self.hidden_dim = hidden_dim
        self.kernel_size = kernel_size
        self.padding = kernel_size // 2
        self.bias = bias

        self.conv = nn.Conv2d(in_channels=self.input_dim + self.hidden_dim,
                              out_channels=4 * self.hidden_dim,
                              kernel_size=self.kernel_size,
                              padding=self.padding,
                              bias=self.bias)

    def forward(self, input_tensor, cur_state):
        h_cur, c_cur = cur_state
        
        # Concatenate input และ hidden state ปัจจุบันเข้าด้วยกัน
        combined = torch.cat([input_tensor, h_cur], dim=1)
        
        combined_conv = self.conv(combined)
        cc_i, cc_f, cc_o, cc_g = torch.split(combined_conv, self.hidden_dim, dim=1)

        i = torch.sigmoid(cc_i)
        f = torch.sigmoid(cc_f)
        o = torch.sigmoid(cc_o)
        g = torch.tanh(cc_g)

        c_next = f * c_cur + i * g
        h_next = o * torch.tanh(c_next)

        return h_next, c_next

    def init_hidden(self, batch_size, image_size):
        height, width = image_size
        return (torch.zeros(batch_size, self.hidden_dim, height, width, device=self.conv.weight.device),
                torch.zeros(batch_size, self.hidden_dim, height, width, device=self.conv.weight.device))

# --- 2. โมเดลหลัก: Encoder-Decoder ConvLSTM ---
class RainForecastModel(nn.Module):
    def __init__(self):
        super(RainForecastModel, self).__init__()
        
        # --- Encoder (TimeDistributed Conv2D) ---
        # ลดขนาดภาพลง: 800 -> 400 -> 200 -> 100
        self.encoder = nn.Sequential(
            nn.Conv2d(1, 16, kernel_size=3, stride=2, padding=1), # 800->400
            nn.BatchNorm2d(16),
            nn.ReLU(),
            nn.Conv2d(16, 32, kernel_size=3, stride=2, padding=1), # 400->200
            nn.BatchNorm2d(32),
            nn.ReLU(),
            nn.Conv2d(32, 64, kernel_size=3, stride=2, padding=1), # 200->100
            nn.BatchNorm2d(64),
            nn.ReLU()
        )
        
        # --- Spatiotemporal Processing (ConvLSTM) ---
        # ทำงานที่ความละเอียด 100x100
        self.conv_lstm = ConvLSTMCell(input_dim=64, hidden_dim=64, kernel_size=3, bias=True)
        
        # --- Decoder (Upsampling) ---
        # ขยายภาพกลับ: 100 -> 200 -> 400 -> 800
        self.decoder = nn.Sequential(
            nn.ConvTranspose2d(64, 32, kernel_size=3, stride=2, padding=1, output_padding=1), # 100->200
            nn.BatchNorm2d(32),
            nn.ReLU(),
            nn.ConvTranspose2d(32, 16, kernel_size=3, stride=2, padding=1, output_padding=1), # 200->400
            nn.BatchNorm2d(16),
            nn.ReLU(),
            nn.ConvTranspose2d(16, 8, kernel_size=3, stride=2, padding=1, output_padding=1),  # 400->800
            nn.BatchNorm2d(8),
            nn.ReLU(),
            nn.Conv2d(8, 1, kernel_size=3, padding=1), # Final output layer
            nn.Sigmoid() # แปลงค่าเป็นความน่าจะเป็น/ความเข้มฝน 0-1
        )

    def forward(self, x):
        # Input shape: (Batch, Time, Channel, Height, Width) -> (B, 5, 1, 800, 800)
        b, t, c, h, w = x.size()
        
        # 1. Encoder (TimeDistributed implementation)
        # Flatten batch and time dimensions -> (B*T, C, H, W) เพื่อเข้า CNN
        x_flat = x.view(b * t, c, h, w)
        encoded_flat = self.encoder(x_flat)
        
        # Reshape กลับมาเป็น Sequence -> (B, T, Feature, H_small, W_small)
        # H_small, W_small should be 100, 100
        _, c_enc, h_enc, w_enc = encoded_flat.size()
        encoded_seq = encoded_flat.view(b, t, c_enc, h_enc, w_enc)
        
        # 2. ConvLSTM Processing
        # วนลูปตามจำนวน Time steps (5 frames)
        h_state, c_state = self.conv_lstm.init_hidden(b, (h_enc, w_enc))
        
        for t_step in range(t):
            h_state, c_state = self.conv_lstm(encoded_seq[:, t_step, :, :, :], (h_state, c_state))
            
        # เราใช้ Hidden state ตัวสุดท้าย (Last timestep) เพื่อพยากรณ์อนาคต
        # h_state shape: (B, 64, 100, 100)
        
        # 3. Decoder
        output = self.decoder(h_state)
        
        return output